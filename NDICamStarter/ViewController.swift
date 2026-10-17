
import UIKit
import AVFoundation

final class ViewController: UIViewController {
    private let cam = CameraCapture()
    private let audio = AudioCapture()
    private var ndi: NDISender?

    private let previewView = UIView()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    private let startStop = UIButton(type: .system)
    private let statusLabel = UILabel()

    private var isStreaming = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "NDI Camera"
        view.backgroundColor = .systemBackground
        setupUI()
        requestPermissionsAndConfigure()
    }

    private func setupUI() {
        previewView.translatesAutoresizingMaskIntoConstraints = false
        startStop.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        startStop.setTitle("Start NDI", for: .normal)
        startStop.addTarget(self, action: #selector(toggleStream), for: .touchUpInside)

        statusLabel.text = "Idle"
        statusLabel.textAlignment = .center
        statusLabel.font = .systemFont(ofSize: 14, weight: .medium)

        view.addSubview(previewView)
        view.addSubview(startStop)
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            previewView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            previewView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            previewView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            previewView.heightAnchor.constraint(equalTo: previewView.widthAnchor, multiplier: 16.0/9.0),

            startStop.topAnchor.constraint(equalTo: previewView.bottomAnchor, constant: 16),
            startStop.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            statusLabel.topAnchor.constraint(equalTo: startStop.bottomAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
    }

    private func requestPermissionsAndConfigure() {
        AVCaptureDevice.requestAccess(for: .video) { _ in }
        AVAudioApplication.requestRecordPermission { _ in }
        DispatchQueue.main.async { [weak self] in
            self?.configureCapture()
        }
    }

    private func configureCapture() {
        do {
            try cam.configureFrontCamera(preset: .hd1280x720)
            let layer = AVCaptureVideoPreviewLayer(session: cam.session)
            layer.frame = previewView.bounds
            layer.videoGravity = .resizeAspectFill
            previewView.layer.addSublayer(layer)
            previewLayer = layer

            cam.onSampleBuffer = { [weak self] sbuf in
                self?.handleVideoBuffer(sbuf)
            }

            try audio.configure(sampleRate: 48_000, channels: 2)
            audio.onBuffer = { [weak self] buffer, fmt, time in
                self?.handleAudioBuffer(buffer, format: fmt, time: time)
            }
        } catch {
            statusLabel.text = "Configure error: \(error.localizedDescription)"
        }
    }

    @objc private func toggleStream() {
        if isStreaming {
            stopStreaming()
        } else {
            startStreaming()
        }
    }

    private func startStreaming() {
        ndi = NDISender(name: UIDevice.current.name + " FrontCam", clockAudio: true)
        cam.start()
        do { try audio.start() } catch { print("Audio start error:", error) }
        isStreaming = true
        startStop.setTitle("Stop NDI", for: .normal)
        statusLabel.text = "Streaming via NDI…"
    }

    private func stopStreaming() {
        cam.stop()
        audio.stop()
        ndi?.destroy()
        ndi = nil
        isStreaming = false
        startStop.setTitle("Start NDI", for: .normal)
        statusLabel.text = "Stopped"
    }

    private func handleVideoBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard isStreaming, let ndi else { return }
        guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let w = Int(CVPixelBufferGetWidth(pb))
        let h = Int(CVPixelBufferGetHeight(pb))
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let ns = Int64((pts.seconds * 1_000_000_000.0).rounded())

        ndi.sendBGRAFrame(pb, width: Int32(w), height: Int32(h), timecodeNS: ns)
    }

    private func handleAudioBuffer(_ buffer: AVAudioPCMBuffer, format: AVAudioFormat, time: AVAudioTime) {
        guard isStreaming, let ndi else { return }
        // Ideally convert hostTime or sampleTime to a monotonic ns if needed.
        let nowNS = Int64(DispatchTime.now().uptimeNanoseconds)
        ndi.sendPCMBuffer(buffer, sampleRate: Int32(format.sampleRate), timecodeNS: nowNS)
    }
}
