// Foundation check against the real app model (no Xcode or app UI required):
// swiftc -swift-version 5 CalorieCompass/Models.swift CalorieCompass/OpenFoodFactsClient.swift Tests/BarcodeLookupChecks.swift -o /tmp/nibble-barcode-checks
// /tmp/nibble-barcode-checks
//
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@main
struct BarcodeLookupChecks {
    static let barcode = "3017620422003"
    static var checks = 0

    static func main() async throws {
        try barcodeChecks()
        try mappingChecks()
        try await httpChecks()
        print("Passed \(checks) barcode lookup checks.")
    }

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw CheckFailure(message: message) }
        checks += 1
    }

    static func expectError(_ expected: FoodLookupError, _ action: () throws -> Void) throws {
        do {
            try action()
            throw CheckFailure(message: "Expected \(expected)")
        } catch let error as FoodLookupError {
            try expect(error == expected, "Expected \(expected), received \(error)")
        }
    }

    static func map(_ product: String) throws -> FoodItem {
        try OpenFoodFactsClient.mapProduct(data: Data("""
        {"status":1,"product":\(product)}
        """.utf8), barcode: barcode)
    }

    static func barcodeChecks() throws {
        for code in ["96385074", "036000291452", barcode, "10012345000017", "0036000291452"] {
            let normalized = try OpenFoodFactsClient.normalizedBarcode(code)
            try expect(normalized == code, "Preserve valid GTIN including leading zeros: \(code)")
        }
        let formatted = try OpenFoodFactsClient.normalizedBarcode(" \n3 017620-422003\r\n")
        try expect(formatted == barcode, "Accept ordinary printed separators")
        for invalid in ["", "1234567", "123456789", "12345678901", "3017620422004", "00000000",
                        "00000000000000", "x3017620422003", "3017620422003x", "３０１７６２０４２２００３",
                        "٣٠١٧٦٢٠٤٢٢٠٠٣", "3017620/422003", "3017620422003.0", "+3017620422003"] {
            try expectError(.invalidBarcode) { _ = try OpenFoodFactsClient.normalizedBarcode(invalid) }
        }

        // GS1 zero-suppression examples exercise all four expansion rules.
        for (compressed, expanded) in [("01234558", "012345000058"), ("04567840", "045670000080"),
                                       ("03456703", "034000005673"), ("09847531", "098400000751")] {
            let result = try OpenFoodFactsClient.normalizedBarcode(compressed, isUPCE: true)
            try expect(result == expanded, "Expand UPC-E \(compressed)")
        }
        try expectError(.invalidBarcode) { _ = try OpenFoodFactsClient.normalizedBarcode("09847532", isUPCE: true) }
        try expectError(.invalidBarcode) { _ = try OpenFoodFactsClient.normalizedBarcode("29847531", isUPCE: true) }
        try expectError(.invalidBarcode) { _ = try OpenFoodFactsClient.normalizedBarcode("984753", isUPCE: true) }
    }

    static func mappingChecks() throws {
        let zero = try map("""
        {"product_name":"  Sparkling water \\n","brands":"  , Sample Brand , Other",
         "serving_quantity_unit":"ml","product_quantity_unit":"ml",
         "nutriments":{"energy-kcal_100g":0,"energy-kj_100g":4.184,"fat_100g":"0","proteins_100g":0,"carbohydrates_100g":0}}
        """)
        try expect(zero.name == "Sparkling water", "Trim product name")
        try expect(zero.brand == "Sample Brand", "Trim first nonempty brand")
        try expect(zero.calories == 0 && zero.fat == 0, "Zero calories and explicit zero macros stay valid")
        try expect(zero.protein == 0 && zero.carbs == 0, "Preserve explicitly reported zero macros")
        try expect(zero.barcode == barcode && zero.source == .openFoodFacts, "Keep source and barcode")
        try expect(zero.servingText == "per 100 ml", "Label explicitly known liquid basis")

        let mixed = try map("""
        {"product_name":"Yogurt","product_quantity_unit":"g",
         "nutriments":{"energy-kcal_100g":" 123.5 ","proteins_100g":"3.2","carbohydrates_100g":4.5,"fat_100g":0}}
        """)
        try expect(mixed.calories == 123.5 && mixed.protein == 3.2 && mixed.carbs == 4.5 && mixed.fat == 0,
                   "Decode JSON numbers and numeric strings")
        try expect(mixed.servingText == "per 100 g", "Label explicitly known mass basis")

        let currentAPI = try OpenFoodFactsClient.mapProduct(data: Data(#"{"status":"success_with_warnings","code":"3017620422003","product":{"product_name":"Current API snack","product_quantity_unit":"g","nutriments":{"energy-kcal_100g":200,"proteins_100g":5,"carbohydrates_100g":20,"fat_100g":8}}}"#.utf8), barcode: barcode)
        try expect(currentAPI.name == "Current API snack" && currentAPI.calories == 200,
                   "Decode the current Open Food Facts API status and product envelope")
        try expectError(.notFound) {
            _ = try OpenFoodFactsClient.mapProduct(data: Data(#"{"status":"failure","result":{"id":"product_not_found"}}"#.utf8), barcode: barcode)
        }

        for key in ["energy-kj_100g", "energy_100g"] {
            let converted = try map("""
            {"product_name":"Juice","nutriments":{"energy-kcal_100g":"unknown","\(key)":"418.4","energy_unit":"kcal",
             "proteins_100g":0,"carbohydrates_100g":0,"fat_100g":0}}
            """)
            try expect(abs(converted.calories - 100) < 0.000001, "Convert normalized \(key) from kJ")
            try expect(converted.servingText == "per 100 g", "Use standard 100 g basis without explicit liquid metadata")
        }
        let energyPriority = try map("""
        {"product_name":"Juice","nutriments":{"energy-kj_100g":418.4,"energy_100g":836.8,
         "proteins_100g":0,"carbohydrates_100g":0,"fat_100g":0}}
        """)
        try expect(abs(energyPriority.calories - 100) < 0.000001, "Prefer explicit kJ over legacy energy")
        let kjZero = try map("""
        {"product_name":"Water","nutriments":{"energy_100g":0,"proteins_100g":0,"carbohydrates_100g":0,"fat_100g":0}}
        """)
        try expect(kjZero.calories == 0, "Zero kJ is usable nutrition")

        for invalid in ["null", "\"\"", "\"unknown\"", "\"NaN\"", "\"Infinity\"", "\"1e999\"",
                        "-1", "\"-2\"", "true", "{}", "[]", "\"3,5\"", "\"<0.5\"", "1e100"] {
            for nutrient in ["energy-kcal_100g", "proteins_100g", "carbohydrates_100g", "fat_100g"] {
                let values = ["energy-kcal_100g", "proteins_100g", "carbohydrates_100g", "fat_100g"]
                    .map { "\"\($0)\":\($0 == nutrient ? invalid : "0")" }.joined(separator: ",")
                try expectError(.missingNutrition) {
                    _ = try map("""
                    {"product_name":"Invalid nutrient","nutriments":{\(values)}}
                    """)
                }
            }
        }

        let fallback = try map("""
        {"product_name":" ","product_name_en":"  Oats ","brands":123,
         "nutriments":{"energy-kcal_100g":350,"proteins_100g":8,"carbohydrates_100g":60,"fat_100g":7}}
        """)
        try expect(fallback.name == "Oats" && fallback.brand == nil && fallback.calories == 350 && fallback.protein == 8,
                   "Name fallback and invalid optional text")
        let generic = try map("""
        {"generic_name":"Rolled oats","nutriments":{"energy-kcal_100g":350,"proteins_100g":8,"carbohydrates_100g":60,"fat_100g":7}}
        """)
        try expect(generic.name == "Rolled oats", "Generic name fallback")
        try expectError(.missingNutrition) {
            _ = try map("""
            {"product_name":"Ambiguous","serving_quantity_unit":"g","product_quantity_unit":"ml",
             "nutriments":{"energy-kcal_100g":50,"proteins_100g":0,"carbohydrates_100g":0,"fat_100g":0}}
            """)
        }

        for unit in ["oz", "fl oz", "l", "unknown"] {
            try expectError(.missingNutrition) {
                _ = try map("""
                {"product_name":"Unclear unit","product_quantity_unit":"\(unit)",
                 "nutriments":{"energy-kcal_100g":50,"proteins_100g":0,"carbohydrates_100g":0,"fat_100g":0}}
                """)
            }
        }
        let liquid = try map("""
        {"product_name":"Water","product_quantity_unit":" ML ",
         "nutriments":{"energy-kcal_100g":0,"proteins_100g":0,"carbohydrates_100g":0,"fat_100g":0}}
        """)
        try expect(liquid.servingText == "per 100 ml", "Normalize explicit liquid unit metadata")

        for product in [
            #"{"product_name":"No nutrition"}"#,
            #"{"product_name":"No nutrition","nutriments":{}}"#,
            #"{"product_name":"No nutrition","nutriments":[]}"#,
            #"{"product_name":"No nutrition","nutriments":{"energy-kcal_100g":"unknown","fat_100g":-1}}"#,
            #"{"product_name":"Serving only","nutriments":{"energy-kcal_serving":100,"fat_serving":2}}"#,
            #"{"product_name":"Prepared only","nutriments":{"energy-kcal_prepared_100g":100}}"#,
            #"{"product_name":"Calories only","nutriments":{"energy-kcal_100g":0}}"#,
            #"{"product_name":"No calories","nutriments":{"proteins_100g":0,"carbohydrates_100g":0,"fat_100g":0}}"#,
            #"{"product_name":"No protein","nutriments":{"energy-kcal_100g":0,"carbohydrates_100g":0,"fat_100g":0}}"#,
            #"{"product_name":"No carbs","nutriments":{"energy-kcal_100g":0,"proteins_100g":0,"fat_100g":0}}"#,
            #"{"product_name":"No fat","nutriments":{"energy-kcal_100g":0,"proteins_100g":0,"carbohydrates_100g":0}}"#,
            #"{"product_name":"Flagged","no_nutrition_data":"on","nutriments":{"energy-kcal_100g":0,"proteins_100g":0,"carbohydrates_100g":0,"fat_100g":0}}"#,
            #"{"product_name":"Flagged","no_nutrition_data":1,"nutriments":{"energy-kcal_100g":0,"proteins_100g":0,"carbohydrates_100g":0,"fat_100g":0}}"#,
            #"{"product_name":"Flagged","no_nutrition_data":true,"nutriments":{"energy-kcal_100g":0,"proteins_100g":0,"carbohydrates_100g":0,"fat_100g":0}}"#
        ] {
            try expectError(.missingNutrition) { _ = try map(product) }
        }
        try expectError(.missingProductName) { _ = try map(#"{"product_name":" ","nutriments":{"energy-kcal_100g":20}}"#) }
        for body in ["not json", "{}", #"{"status":1}"#, #"{"status":1,"product":null}"#,
                     #"{"status":1,"product":[]}"#, #"{"status":2}"#, #"{"status":"1"}"#] {
            try expectError(.invalidResponse) {
                _ = try OpenFoodFactsClient.mapProduct(data: Data(body.utf8), barcode: barcode)
            }
        }
        try expectError(.notFound) {
            _ = try OpenFoodFactsClient.mapProduct(data: Data(#"{"status":0,"product":"ignored"}"#.utf8), barcode: barcode)
        }
    }

    static func httpChecks() async throws {
        let configuration = OpenFoodFactsClient.lookupConfiguration()
        try expect(configuration.urlCache == nil, "Barcode responses have no HTTP cache")
        try expect(configuration.urlCredentialStorage == nil, "Public reads have no credential storage")
        try expect(configuration.httpCookieStorage == nil, "Barcode requests have no cookie jar")
        try expect(!configuration.httpShouldSetCookies && configuration.httpCookieAcceptPolicy == .never,
                   "Do not accept provider cookies")
        try expect(configuration.requestCachePolicy == .reloadIgnoringLocalCacheData, "Ignore old cached lookups")
        configuration.protocolClasses = [FixtureURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let client = OpenFoodFactsClient(session: session)
        let success = Data(#"{"status":"success","code":"3017620422003","product":{"product_name":"Test","product_quantity_unit":"g","nutriments":{"energy-kcal_100g":0,"proteins_100g":0,"carbohydrates_100g":0,"fat_100g":0}}}"#.utf8)
        FixtureURLProtocol.configure(.http(200, success))
        let food = try await client.lookup(barcode: barcode)
        try expect(food.calories == 0, "Injected session success")
        let request = FixtureURLProtocol.lastRequest
        try expect(request?.url?.host == "world.openfoodfacts.org"
                   && request?.url?.path == "/api/v3/product/\(barcode)", "Build the current product URL")
        try expect(request?.value(forHTTPHeaderField: "User-Agent")?.hasPrefix("Nibble/") == true,
                   "Identify the app to Open Food Facts")
        try expect(request?.value(forHTTPHeaderField: "Accept") == "application/json", "Request JSON")
        try expect(request?.timeoutInterval == 12, "Bound request timeout")
        try expect(request?.cachePolicy == .reloadIgnoringLocalCacheData, "Request cannot opt back into persistent caching")
        try expect(request?.httpShouldHandleCookies == false, "Request cannot opt back into cookie handling")
        try expect(request?.httpMethod == "GET" && request?.httpBody == nil, "Only a public product read is sent")
        try expect(request?.value(forHTTPHeaderField: "Authorization") == nil && request?.value(forHTTPHeaderField: "Cookie") == nil,
                   "No credentials or cookies are attached")
        let fields = request?.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?
            .queryItems?.first(where: { $0.name == "fields" })?.value
        try expect(fields?.contains("nutriments") == true && fields?.contains("product_quantity_unit") == true,
                   "Request nutrition and unit fields")
        let productType = request?.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?
            .queryItems?.first(where: { $0.name == "product_type" })?.value
        try expect(productType == "food", "Limit lookups to food products")

        for (status, expected) in [(404, FoodLookupError.notFound), (429, .rateLimited),
                                   (503, .httpError(statusCode: 503)), (403, .httpError(statusCode: 403))] {
            FixtureURLProtocol.configure(.http(status, Data("not json".utf8)))
            try await expectLookupError(expected, client: client)
        }
        FixtureURLProtocol.configure(.http(200, Data("not json".utf8)))
        try await expectLookupError(.invalidResponse, client: client)
        FixtureURLProtocol.configure(.http(200, Data(#"{"status":0}"#.utf8)))
        try await expectLookupError(.notFound, client: client)
        FixtureURLProtocol.configure(.http(204, Data()))
        try await expectLookupError(.invalidResponse, client: client)

        for (code, expected) in [(URLError.notConnectedToInternet, FoodLookupError.offline),
                                 (.networkConnectionLost, .offline), (.timedOut, .timedOut),
                                 (.cannotConnectToHost, .requestFailed)] {
            FixtureURLProtocol.configure(.failure(code))
            try await expectLookupError(expected, client: client)
        }
        FixtureURLProtocol.configure(.failure(.cancelled))
        do {
            _ = try await client.lookup(barcode: barcode)
            throw CheckFailure(message: "URLSession cancellation must propagate")
        } catch is CancellationError { checks += 1 }

        FixtureURLProtocol.configure(.http(200, success))
        do {
            _ = try await client.lookup(barcode: "junk")
            throw CheckFailure(message: "Invalid barcode must fail before sending")
        } catch let error as FoodLookupError {
            try expect(error == .invalidBarcode && FixtureURLProtocol.requestCount == 0, "Validate before network I/O")
        }

        let alreadyCancelled = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await client.lookup(barcode: barcode)
        }
        do {
            _ = try await alreadyCancelled.value
            throw CheckFailure(message: "Pre-cancelled lookup must not send")
        } catch is CancellationError {
            try expect(FixtureURLProtocol.requestCount == 0, "Pre-cancelled lookup sends no request")
        }

        let started = AsyncStream<Void>.makeStream()
        let stopped = AsyncStream<Void>.makeStream()
        defer {
            started.continuation.finish()
            stopped.continuation.finish()
        }
        FixtureURLProtocol.configure(.pending, onStart: { started.continuation.yield(()) },
                                     onStop: { stopped.continuation.yield(()) })
        let pending = Task { try await client.lookup(barcode: barcode) }
        for await _ in started.stream { break }
        pending.cancel()
        do {
            _ = try await pending.value
            throw CheckFailure(message: "In-flight cancellation must propagate")
        } catch is CancellationError { checks += 1 }
        for await _ in stopped.stream { break }
        try expect(FixtureURLProtocol.requestCount == 1, "Task cancellation stops the underlying request")
    }

    static func expectLookupError(_ expected: FoodLookupError, client: OpenFoodFactsClient) async throws {
        do {
            _ = try await client.lookup(barcode: barcode)
            throw CheckFailure(message: "Expected lookup error \(expected)")
        } catch let error as FoodLookupError {
            try expect(error == expected, "Expected lookup error \(expected), got \(error)")
        }
    }
}

private struct CheckFailure: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}

/// A deterministic URLSession transport: fixtures never contact the public API.
private final class FixtureURLProtocol: URLProtocol {
    enum Plan {
        case http(Int, Data)
        case failure(URLError.Code)
        case pending
    }
    private static let lock = NSLock()
    private static var plan: Plan = .pending
    private static var startCallback: (() -> Void)?
    private static var stopCallback: (() -> Void)?
    private static var recordedRequest: URLRequest?
    private static var count = 0

    static var lastRequest: URLRequest? {
        lock.lock()
        defer { lock.unlock() }
        return recordedRequest
    }

    static var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    static func configure(_ plan: Plan, onStart: (() -> Void)? = nil, onStop: (() -> Void)? = nil) {
        lock.lock()
        defer { lock.unlock() }
        self.plan = plan
        startCallback = onStart
        stopCallback = onStop
        recordedRequest = nil
        count = 0
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        let plan = Self.plan
        let onStart = Self.startCallback
        Self.recordedRequest = request
        Self.count += 1
        Self.lock.unlock()
        onStart?()
        switch plan {
        case let .http(status, data):
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1",
                                           headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case let .failure(code):
            client?.urlProtocol(self, didFailWithError: URLError(code))
        case .pending:
            break
        }
    }

    override func stopLoading() {
        Self.lock.lock()
        let onStop = Self.stopCallback
        Self.lock.unlock()
        onStop?()
    }
}
