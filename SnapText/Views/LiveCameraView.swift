import SwiftUI
import AVFoundation
import Combine

/// Full AVFoundation camera with flashlight toggle, replacing UIImagePickerController.
struct LiveCameraView: View {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Live preview
            CameraPreviewLayer(session: camera.session)
                .ignoresSafeArea()

            VStack {
                // Top bar
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.ultraThinMaterial.opacity(0.6))
                            .clipShape(Circle())
                    }

                    Spacer()

                    if camera.hasFlash {
                        Button { camera.toggleFlash() } label: {
                            Image(systemName: camera.flashOn ? "bolt.fill" : "bolt.slash.fill")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(camera.flashOn ? .yellow : .white)
                                .padding(12)
                                .background(.ultraThinMaterial.opacity(0.6))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Spacer()

                // Bottom controls
                HStack(spacing: 40) {
                    // Gallery placeholder spacer
                    Color.clear.frame(width: 50, height: 50)

                    // Capture button
                    Button {
                        camera.capturePhoto { image in
                            if let image {
                                onImageCaptured(image)
                                dismiss()
                            }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(.white, lineWidth: 4)
                                .frame(width: 72, height: 72)
                            Circle()
                                .fill(.white)
                                .frame(width: 60, height: 60)
                        }
                    }

                    // Flip camera
                    Button { camera.flipCamera() } label: {
                        Image(systemName: "camera.rotate")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 50, height: 50)
                            .background(.ultraThinMaterial.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom, 40)
            }

            if camera.isTaking {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .statusBarHidden()
    }
}

// MARK: - Camera Model

final class CameraModel: NSObject, ObservableObject {
    let session = AVCaptureSession()

    @Published var flashOn = false
    @Published var hasFlash = false
    @Published var isTaking = false

    private var device: AVCaptureDevice?
    private let output = AVCapturePhotoOutput()
    private var completion: ((UIImage?) -> Void)?
    private var position: AVCaptureDevice.Position = .back

    func start() {
        checkPermission { [weak self] granted in
            guard granted else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                self?.setupSession()
            }
        }
    }

    func stop() {
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.stopRunning()
            }
        }
    }

    func toggleFlash() {
        flashOn.toggle()
    }

    func flipCamera() {
        position = (position == .back) ? .front : .back
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.setupSession()
        }
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
        let settings = AVCapturePhotoSettings()
        if hasFlash {
            settings.flashMode = flashOn ? .on : .off
        }
        DispatchQueue.main.async { self.isTaking = true }
        output.capturePhoto(with: settings, delegate: self)
    }

    private func checkPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                completion(granted)
            }
        default:
            completion(false)
        }
    }

    private func setupSession() {
        session.beginConfiguration()
        session.inputs.forEach { session.removeInput($0) }

        guard let cam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: cam) else {
            session.commitConfiguration()
            return
        }

        device = cam
        DispatchQueue.main.async { self.hasFlash = cam.hasFlash }

        if session.canAddInput(input) { session.addInput(input) }
        if !session.outputs.contains(output), session.canAddOutput(output) {
            session.addOutput(output)
        }

        session.sessionPreset = .photo
        session.commitConfiguration()

        if !session.isRunning { session.startRunning() }
    }
}

extension CameraModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        DispatchQueue.main.async { self.isTaking = false }
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            completion?(nil)
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.completion?(image)
        }
    }
}

// MARK: - Preview Layer

struct CameraPreviewLayer: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = CameraPreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    private class CameraPreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
