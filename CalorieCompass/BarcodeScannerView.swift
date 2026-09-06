import SwiftUI

#if os(iOS)
import AVFoundation
import UIKit

struct BarcodeScannerView: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.onCode = onCode
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {
        uiViewController.onCode = onCode
    }

    static func dismantleUIViewController(_ uiViewController: ScannerViewController, coordinator: ()) {
        uiViewController.shutdown()
    }
}

final class ScannerViewController: UIViewController {
    var onCode: ((String) -> Void)?
    private let camera = BarcodeCapture()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let messageLabel = UILabel()
    private let settingsButton = UIButton(type: .system)
    private let statusStack = UIStackView()
    private var isVisible = false
    private var isActive = false
    private var isDismantled = false
    private var isRequestingPermission = false
    private var didScan = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        let layer = AVCaptureVideoPreviewLayer(session: camera.session)
        layer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer

        messageLabel.textColor = .white
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.font = .preferredFont(forTextStyle: .body)
        messageLabel.adjustsFontForContentSizeCategory = true
        settingsButton.setTitle("Open Settings", for: .normal)
        settingsButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        settingsButton.titleLabel?.adjustsFontForContentSizeCategory = true
        settingsButton.tintColor = .white
        settingsButton.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
        statusStack.axis = .vertical
        statusStack.alignment = .center
        statusStack.spacing = 20
        statusStack.addArrangedSubview(messageLabel)
        statusStack.addArrangedSubview(settingsButton)
        statusStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusStack)
        NSLayoutConstraint.activate([
            statusStack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 28),
            statusStack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -28),
            statusStack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            settingsButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
        showCameraMessage("Preparing the barcode scanner…")
        NotificationCenter.default.addObserver(self, selector: #selector(becameActive),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resignedActive),
                                               name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(captureInterrupted),
                                               name: AVCaptureSession.wasInterruptedNotification, object: camera.session)
        NotificationCenter.default.addObserver(self, selector: #selector(captureInterruptionEnded),
                                               name: AVCaptureSession.interruptionEndedNotification, object: camera.session)
        NotificationCenter.default.addObserver(self, selector: #selector(captureFailed),
                                               name: AVCaptureSession.runtimeErrorNotification, object: camera.session)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isVisible = true
        isActive = UIApplication.shared.applicationState == .active
        updateCamera()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isVisible = false
        camera.stop()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        guard let connection = previewLayer?.connection,
              let orientation = view.window?.windowScene?.interfaceOrientation else { return }
        let angle: CGFloat
        switch orientation {
        case .portrait: angle = 90
        case .portraitUpsideDown: angle = 270
        case .landscapeLeft: angle = 0
        case .landscapeRight: angle = 180
        default: return
        }
        if connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
    }

    /// Called by SwiftUI as well as the normal view lifecycle; safe to call more than once.
    func shutdown() {
        isDismantled = true
        isVisible = false
        onCode = nil
        camera.stop()
        NotificationCenter.default.removeObserver(self)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        // stop() retains only the capture worker until its serial queue has stopped the session.
        camera.stop()
    }

    @objc private func becameActive() {
        isActive = true
        updateCamera()
    }

    @objc private func resignedActive() {
        isActive = false
        camera.stop()
    }

    @objc private func captureInterrupted() {
        // Capture notifications may be posted on the capture queue.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.canScan else { return }
            self.camera.stop()
            self.showCameraMessage("Camera scanning is paused. You can close this view and type the barcode.")
        }
    }

    @objc private func captureInterruptionEnded() {
        DispatchQueue.main.async { [weak self] in self?.updateCamera() }
    }

    @objc private func captureFailed() {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.canScan else { return }
            self.camera.stop()
            self.showCameraMessage("The camera stopped unexpectedly. Close and reopen the scanner, or type the barcode.")
        }
    }

    private var canScan: Bool { isVisible && isActive && !isDismantled && !didScan }

    private func updateCamera() {
        guard canScan else { return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            statusStack.isHidden = true
            camera.start(onCode: { [weak self] code in
                guard let self, self.canScan else { return }
                self.didScan = true
                self.camera.stop()
                self.onCode?(code)
            }, onFailure: { [weak self] message in
                guard let self, self.canScan else { return }
                self.showCameraMessage(message)
            })
        case .notDetermined:
            guard !isRequestingPermission else { return }
            isRequestingPermission = true
            showCameraMessage("Allow camera access to scan a food barcode.")
            AVCaptureDevice.requestAccess(for: .video) { [weak self] _ in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.isRequestingPermission = false
                    // Recheck authorization and visibility; a prompt can outlive this sheet.
                    self.updateCamera()
                }
            }
        case .denied:
            camera.stop()
            showCameraMessage("Camera access is off. Allow access in Settings, or close the scanner and type the barcode.",
                              showsSettings: true)
        case .restricted:
            camera.stop()
            showCameraMessage("Camera access is restricted on this device. Close the scanner and type the barcode.")
        @unknown default:
            camera.stop()
            showCameraMessage("Camera scanning is unavailable. Close the scanner and type the barcode.")
        }
    }

    @objc private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func showCameraMessage(_ message: String, showsSettings: Bool = false) {
        messageLabel.text = message
        settingsButton.isHidden = !showsSettings
        statusStack.isHidden = false
    }
}

/// All capture configuration, state, and metadata delivery are confined to this serial queue.
/// The UI receives callbacks on main and checks its own visibility before delivering onCode.
private final class BarcodeCapture: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "app.nibble.barcode.capture", qos: .userInitiated)
    private var isConfigured = false
    private var isEnabled = false
    private var didDeliverCode = false
    private var onCode: ((String) -> Void)?
    private var output: AVCaptureMetadataOutput?

    func start(onCode: @escaping (String) -> Void, onFailure: @escaping (String) -> Void) {
        queue.async { [self] in
            self.onCode = onCode
            isEnabled = true
            didDeliverCode = false
            do {
                try configureIfNeeded()
                if !session.isRunning { session.startRunning() }
                if !session.isRunning {
                    isEnabled = false
                    DispatchQueue.main.async { onFailure("The camera could not start. Close the scanner and type the barcode.") }
                }
            } catch {
                isEnabled = false
                DispatchQueue.main.async { onFailure(error.localizedDescription) }
            }
        }
    }

    func stop() {
        queue.async { [self] in
            isEnabled = false
            onCode = nil
            if session.isRunning { session.stopRunning() }
        }
    }

    private func configureIfNeeded() throws {
        guard !isConfigured else { return }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(for: .video) else {
            throw CaptureError.unavailable
        }
        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            throw CaptureError.unavailable
        }

        session.beginConfiguration()
        defer { session.commitConfiguration() }
        if session.canSetSessionPreset(.high) { session.sessionPreset = .high }
        guard session.canAddInput(input) else { throw CaptureError.unavailable }
        session.addInput(input)

        let metadata = AVCaptureMetadataOutput()
        guard session.canAddOutput(metadata) else {
            session.removeInput(input)
            throw CaptureError.unsupported
        }
        session.addOutput(metadata)
        // Assigning unsupported types raises an Objective-C exception, so filter after attaching output.
        let supported: [AVMetadataObject.ObjectType] = [.ean8, .ean13, .upce, .itf14, .code128]
        let available = supported.filter { metadata.availableMetadataObjectTypes.contains($0) }
        guard !available.isEmpty else {
            session.removeOutput(metadata)
            session.removeInput(input)
            throw CaptureError.unsupported
        }
        metadata.metadataObjectTypes = available
        metadata.setMetadataObjectsDelegate(self, queue: queue)
        output = metadata
        isConfigured = true
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard isEnabled, !didDeliverCode else { return }
        for case let object as AVMetadataMachineReadableCodeObject in metadataObjects {
            guard output.metadataObjectTypes.contains(object.type),
                  let rawCode = object.stringValue,
                  let code = try? OpenFoodFactsClient.normalizedBarcode(rawCode, isUPCE: object.type == .upce) else { continue }
            didDeliverCode = true
            isEnabled = false
            let callback = onCode
            onCode = nil
            if session.isRunning { session.stopRunning() }
            DispatchQueue.main.async { callback?(code) }
            return
        }
    }

    private enum CaptureError: LocalizedError {
        case unavailable, unsupported

        var errorDescription: String? {
            switch self {
            case .unavailable: return "This device camera is unavailable. Close the scanner and type the barcode."
            case .unsupported: return "Barcode scanning is unavailable on this device. Close the scanner and type the barcode."
            }
        }
    }
}
#else
/// Keeps shared SwiftUI screens available in macOS previews without importing UIKit.
struct BarcodeScannerView: View {
    let onCode: (String) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 44))
                .accessibilityHidden(true)
            Text("Scan with Nibble on iPhone")
                .font(.headline)
            Text("Camera barcode scanning is available on iOS. Close this view and type the product barcode to look it up.")
                .multilineTextAlignment(.center)
                .font(.body)
        }
        .foregroundStyle(.white)
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}
#endif
