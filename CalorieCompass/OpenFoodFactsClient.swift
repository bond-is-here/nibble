import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum FoodLookupError: LocalizedError, Equatable {
    case invalidBarcode
    case notFound
    case missingNutrition
    case missingProductName
    case invalidResponse
    case offline
    case timedOut
    case rateLimited
    case httpError(statusCode: Int)
    case requestFailed

    var errorDescription: String? {
        switch self {
        case .invalidBarcode:
            return "Enter an 8, 12, 13, or 14 digit product barcode with a valid check digit."
        case .notFound:
            return "We couldn’t find that barcode. Try searching by name."
        case .missingNutrition:
            return "That product has incomplete nutrition or an unclear portion basis. Enter the label values manually."
        case .missingProductName:
            return "That barcode has no product name. Check the label and add it manually."
        case .invalidResponse:
            return "Open Food Facts returned an unreadable product. Try again."
        case .offline:
            return "You appear to be offline. Check your connection and try again."
        case .timedOut:
            return "The barcode lookup took too long. Try again."
        case .rateLimited:
            return "Open Food Facts is receiving too many requests. Wait a moment and try again."
        case .httpError, .requestFailed:
            return "Lookup is unavailable right now. Try again or use a saved food."
        }
    }
}

struct OpenFoodFactsClient {
    private let session: URLSession
    private static let lookupSession = URLSession(configuration: sessionConfiguration())

    init(session: URLSession? = nil) {
        self.session = session ?? Self.lookupSession
    }

    /// Public nutrition reads need no persistent cookies, credentials, or HTTP cache.
    /// Logged/favorited products remain available through the protected diary archive.
    static func lookupConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.urlCredentialStorage = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return configuration
    }

    private static func sessionConfiguration() -> URLSessionConfiguration {
        let configuration = lookupConfiguration()
        #if DEBUG
        // Only a UUID-isolated UI test can replace the transport. The fixture and
        // override do not exist in Release; no real barcode request is sent here.
        if let value = ProcessInfo.processInfo.environment["NIBBLE_UI_TEST_ID"], UUID(uuidString: value) != nil,
           ["delayed-product", "offline"].contains(ProcessInfo.processInfo.environment["NIBBLE_UI_TEST_BARCODE"] ?? "") {
            configuration.protocolClasses = [UITestProductProtocol.self]
        }
        #endif
        return configuration
    }

    func lookup(barcode: String) async throws -> FoodItem {
        try Task.checkCancellation()
        let normalized = try Self.normalizedBarcode(barcode)
        guard var components = URLComponents(string: "https://world.openfoodfacts.org/api/v3/product/\(normalized)") else {
            throw FoodLookupError.invalidBarcode
        }
        components.queryItems = [
            URLQueryItem(name: "product_type", value: "food"),
            URLQueryItem(name: "lc", value: "en"),
            URLQueryItem(
                name: "fields",
                value: "product_name,product_name_en,generic_name,brands,nutriments,serving_quantity_unit,product_quantity_unit,no_nutrition_data"
            )
        ]
        guard let url = components.url else { throw FoodLookupError.invalidBarcode }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 12)
        request.httpShouldHandleCookies = false
        request.setValue("Nibble/1.0 (+https://github.com/bond-is-here/nibble)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            // URLSession can surface cancellation as URLError.cancelled instead of CancellationError.
            if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled {
                throw CancellationError()
            }
            switch (error as? URLError)?.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
                throw FoodLookupError.offline
            case .timedOut:
                throw FoodLookupError.timedOut
            default:
                throw FoodLookupError.requestFailed
            }
        }
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw FoodLookupError.invalidResponse }
        switch http.statusCode {
        case 200..<300: break
        case 404: throw FoodLookupError.notFound
        case 429: throw FoodLookupError.rateLimited
        default: throw FoodLookupError.httpError(statusCode: http.statusCode)
        }

        let food = try Self.mapProduct(data: data, barcode: normalized)
        try Task.checkCancellation()
        return food
    }

    /// Validates GTIN-8 / UPC-A / EAN-13 / GTIN-14 without discarding letters or Unicode numerals.
    /// The scanner passes isUPCE so compressed UPC-E values cannot be confused with EAN-8.
    static func normalizedBarcode(_ barcode: String, isUPCE: Bool = false) throws -> String {
        var digits = [UInt8]()
        for scalar in barcode.unicodeScalars {
            switch scalar.value {
            case 48...57: digits.append(UInt8(scalar.value - 48))
            case 9, 10, 13, 32, 45: continue // Allow spaces, line breaks, and printed separators.
            default: throw FoodLookupError.invalidBarcode
            }
        }

        if isUPCE {
            guard digits.count == 8, digits[0] <= 1 else { throw FoodLookupError.invalidBarcode }
            let prefix = [digits[0]]
            let check = [digits[7]]
            switch digits[6] {
            case 0...2:
                digits = prefix + Array(digits[1...2]) + [digits[6], 0, 0, 0, 0] + Array(digits[3...5]) + check
            case 3:
                digits = prefix + Array(digits[1...3]) + [0, 0, 0, 0, 0] + Array(digits[4...5]) + check
            case 4:
                digits = prefix + Array(digits[1...4]) + [0, 0, 0, 0, 0, digits[5]] + check
            default:
                digits = prefix + Array(digits[1...5]) + [0, 0, 0, 0, digits[6]] + check
            }
        }

        guard [8, 12, 13, 14].contains(digits.count), digits.contains(where: { $0 != 0 }) else {
            throw FoodLookupError.invalidBarcode
        }
        let checksum = digits.reversed().enumerated().reduce(0) { sum, element in
            sum + Int(element.element) * (element.offset.isMultiple(of: 2) ? 1 : 3)
        }
        guard checksum.isMultiple(of: 10) else { throw FoodLookupError.invalidBarcode }
        return digits.map(String.init).joined()
    }

    /// Pure mapping entry point for fixtures; every nutrition value uses the same 100 g / 100 ml basis.
    static func mapProduct(data: Data, barcode: String) throws -> FoodItem {
        let normalized = try normalizedBarcode(barcode)
        let decoded: OpenFoodFactsResponse
        do {
            decoded = try JSONDecoder().decode(OpenFoodFactsResponse.self, from: data)
        } catch {
            throw FoodLookupError.invalidResponse
        }
        guard decoded.status != .notFound else { throw FoodLookupError.notFound }
        guard decoded.status == .found, let product = decoded.product else { throw FoodLookupError.invalidResponse }
        guard let name = [product.productName, product.productNameEnglish, product.genericName]
            .compactMap({ $0?.nonempty }).first else { throw FoodLookupError.missingProductName }

        let nutrition = product.nutriments
        // OFF's normalized energy_100g and energy-kj_100g are always kJ, regardless of energy_unit.
        let kilojoules = nutrition?.energyKj100g?.value ?? nutrition?.energy100g?.value
        // FoodItem stores concrete values. Refuse incomplete labels instead of inventing macro zeros.
        guard !product.hasNoNutritionData,
              let calories = nutrition?.energyKcal100g?.value ?? kilojoules.map({ $0 / 4.184 }),
              let protein = nutrition?.proteins100g?.value,
              let carbs = nutrition?.carbohydrates100g?.value,
              let fat = nutrition?.fat100g?.value,
              let nutritionBasis = product.nutritionBasis,
              [calories, protein, carbs, fat].allSatisfy({ $0 <= 10_000 }) else {
            throw FoodLookupError.missingNutrition
        }

        return FoodItem(
            name: name,
            brand: product.brands?.split(separator: ",").compactMap { String($0).nonempty }.first,
            servingText: nutritionBasis,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            barcode: normalized,
            source: .openFoodFacts
        )
    }
}

#if DEBUG
/// Deliberately slow transport for the manual-entry cancellation regression.
/// The response traverses the real URLSession and product decoder.
private final class UITestProductProtocol: URLProtocol {
    private let queue = DispatchQueue(label: "app.nibble.uitest.delayed-product")
    private var stopped = false

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if ProcessInfo.processInfo.environment["NIBBLE_UI_TEST_BARCODE"] == "offline" {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        queue.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self else { return }
            guard !self.stopped, let url = self.request.url,
                  let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                                                 headerFields: ["Content-Type": "application/json"]) else { return }
            let data = Data(#"{"status":1,"product":{"product_name":"Delayed test drink","product_quantity_unit":"ml","nutriments":{"energy-kcal_100g":50,"proteins_100g":1,"carbohydrates_100g":10,"fat_100g":0}}}"#.utf8)
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: data)
            self.client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {
        queue.async { [weak self] in self?.stopped = true }
    }
}
#endif

private struct OpenFoodFactsResponse: Decodable {
    enum Status: Equatable {
        case found
        case notFound
        case other
    }

    let status: Status
    let product: OpenFoodFactsProduct?

    enum CodingKeys: String, CodingKey { case status, product }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let legacyStatus = try? container.decode(Int.self, forKey: .status) {
            status = legacyStatus == 1 ? .found : legacyStatus == 0 ? .notFound : .other
        } else if let currentStatus = try? container.decode(String.self, forKey: .status) {
            let normalized = currentStatus.lowercased()
            status = normalized == "failure" ? .notFound : normalized.hasPrefix("success") ? .found : .other
        } else {
            status = .other
        }

        // Keep malformed non-found payloads classified by their status while
        // refusing malformed product objects when the provider says it found one.
        product = status == .found ? try container.decodeIfPresent(OpenFoodFactsProduct.self, forKey: .product) : nil
    }
}

private struct OpenFoodFactsProduct: Decodable {
    let productName: String?
    let productNameEnglish: String?
    let genericName: String?
    let brands: String?
    let nutriments: OpenFoodFactsNutriments?
    let servingQuantityUnit: String?
    let productQuantityUnit: String?
    let hasNoNutritionData: Bool

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case productNameEnglish = "product_name_en"
        case genericName = "generic_name"
        case brands, nutriments
        case servingQuantityUnit = "serving_quantity_unit"
        case productQuantityUnit = "product_quantity_unit"
        case noNutritionData = "no_nutrition_data"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        productName = try? container.decode(String.self, forKey: .productName)
        productNameEnglish = try? container.decode(String.self, forKey: .productNameEnglish)
        genericName = try? container.decode(String.self, forKey: .genericName)
        brands = try? container.decode(String.self, forKey: .brands)
        nutriments = try? container.decode(OpenFoodFactsNutriments.self, forKey: .nutriments)
        servingQuantityUnit = try? container.decode(String.self, forKey: .servingQuantityUnit)
        productQuantityUnit = try? container.decode(String.self, forKey: .productQuantityUnit)
        let noData = try? container.decode(String.self, forKey: .noNutritionData)
        hasNoNutritionData = ["on", "true", "1"].contains(noData?.nonempty?.lowercased() ?? "")
            || (try? container.decode(Bool.self, forKey: .noNutritionData)) == true
            || (try? container.decode(Int.self, forKey: .noNutritionData)) == 1
    }

    var nutritionBasis: String? {
        // The legacy "100g" suffix also represents liquids. Only use explicit normalized unit metadata.
        let units = Set([servingQuantityUnit, productQuantityUnit].compactMap { $0?.nonempty?.lowercased() })
        guard units.isSubset(of: ["g", "ml"]), units.count < 2 else { return nil }
        if units == ["ml"] { return "per 100 ml" }
        return "per 100 g"
    }
}

private struct OpenFoodFactsNutriments: Decodable {
    let energyKcal100g: FlexibleNutritionNumber?
    let energyKj100g: FlexibleNutritionNumber?
    let energy100g: FlexibleNutritionNumber?
    let proteins100g: FlexibleNutritionNumber?
    let carbohydrates100g: FlexibleNutritionNumber?
    let fat100g: FlexibleNutritionNumber?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case energyKj100g = "energy-kj_100g"
        case energy100g = "energy_100g"
        case proteins100g = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case fat100g = "fat_100g"
    }
}

private struct FlexibleNutritionNumber: Decodable {
    let value: Double?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let number: Double?
        if let decoded = try? container.decode(Double.self) {
            number = decoded
        } else if let string = try? container.decode(String.self) {
            number = Double(string.trimmingCharacters(in: .whitespacesAndNewlines))
        } else {
            number = nil
        }
        value = number.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
    }
}

private extension String {
    var nonempty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
