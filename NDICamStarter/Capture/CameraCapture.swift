
import AVFoundation
import UIKit

final class CameraCapture: NSObject {
    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "ndi.cam.video.queue")
    var onSampleBuffer: ((CMSampleBuffer) -> Void)?

    func configureFrontCamera(preset: AVCaptureSession.Preset = .hd1280x720) throws {
        session.beginConfiguration()
        session.sessionPreset = preset

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw NSError(domain: "NDICam", code: -1, userInfo: [NSLocalizedDescriptionKey: "No front camera"])
        }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw NSError(domain: "NDICam", code: -2, userInfo: nil) }
        session.addInput(input)

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(videoOutput) else { throw NSError(domain: "NDICam", code: -3, userInfo: nil) }
        session.addOutput(videoOutput)

        if let conn = videoOutput.connections.first {
            if conn.isVideoOrientationSupported { conn.videoOrientation = .portrait }
            if conn.isVideoMirroringSupported { conn.isVideoMirrored = true } // mirror for selfie preview
        }
        session.commitConfiguration()
    }

    func start() { if !session.isRunning { session.startRunning() } }
    func stop() { if session.isRunning { session.stopRunning() } }
}

extension CameraCapture: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        onSampleBuffer?(sampleBuffer)
    }
}
