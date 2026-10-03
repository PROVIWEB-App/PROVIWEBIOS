import SwiftUI
import AVFoundation

// MARK: - Native QR Code Scanner View (QRScannerActivity equivalent)
public struct QRScannerView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    public var onCodeScanned: ((String) -> Void)?
    
    @State private var scannedCode: String? = nil
    @State private var isFlashlightOn: Bool = false
    
    public init(onCodeScanned: ((String) -> Void)? = nil) {
        self.onCodeScanned = onCodeScanned
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                // Camera Scanner Layer
                QRCameraScannerRepresentable { code in
                    scannedCode = code
                    onCodeScanned?(code)
                    presentationMode.wrappedValue.dismiss()
                }
                .ignoresSafeArea()
                
                // Scanner HUD Overlay
                VStack {
                    Text("Escanea un código QR de Artista, Entrada o Web3")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 40)
                    
                    Spacer()
                    
                    // Reticle Frame
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(AppColors.primary, lineWidth: 3)
                            .frame(width: 250, height: 250)
                        
                        Rectangle()
                            .fill(AppColors.primary.opacity(0.15))
                            .frame(width: 240, height: 240)
                            .cornerRadius(20)
                    }
                    
                    Spacer()
                    
                    // Flashlight & Action Buttons
                    HStack(spacing: 40) {
                        Button(action: {
                            isFlashlightOn.toggle()
                            toggleTorch(on: isFlashlightOn)
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: isFlashlightOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(16)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(Circle())
                                
                                Text("Linterna")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(.bottom, 48)
                }
            }
            .navigationTitle("Escanear QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    private func toggleTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("Torch error: \(error)")
        }
    }
}

// MARK: - UIViewControllerRepresentable for AVCaptureSession
struct QRCameraScannerRepresentable: UIViewControllerRepresentable {
    let onScanned: (String) -> Void
    
    func makeUIViewController(context: Context) -> QRScannerViewController {
        let vc = QRScannerViewController()
        vc.onCodeFound = onScanned
        return vc
    }
    
    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var onCodeFound: ((String) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupScanner()
    }
    
    private func setupScanner() {
        let session = AVCaptureSession()
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
            } else { return }
            
            let metadataOutput = AVCaptureMetadataOutput()
            if session.canAddOutput(metadataOutput) {
                session.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [.qr, .ean13, .ean8, .code128]
            } else { return }
            
            previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer?.frame = view.layer.bounds
            previewLayer?.videoGravity = .resizeAspectFill
            if let preview = previewLayer {
                view.layer.addSublayer(preview)
            }
            
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
            self.captureSession = session
        } catch {
            print("Error initializing QR Scanner: \(error)")
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
           let stringValue = metadataObject.stringValue {
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            captureSession?.stopRunning()
            onCodeFound?(stringValue)
        }
    }
}
