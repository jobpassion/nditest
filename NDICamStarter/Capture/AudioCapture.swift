
import AVFoundation

final class AudioCapture {
    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    var onBuffer: ((AVAudioPCMBuffer, AVAudioFormat, AVAudioTime) -> Void)?

    func configure(sampleRate: Double = 48_000, channels: AVAudioChannelCount = 2) throws {
        let input = engine.inputNode
        let inFormat = input.inputFormat(forBus: 0)
        let desired = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                    sampleRate: sampleRate,
                                    channels: channels,
                                    interleaved: false)!
        converter = AVAudioConverter(from: inFormat, to: desired)

        input.installTap(onBus: 0, bufferSize: 1024, format: inFormat) { [weak self] (buffer, time) in
            guard let self, let converter = self.converter else { return }
            guard let desired = converter.outputFormat else { return }
            let outBuffer = AVAudioPCMBuffer(pcmFormat: desired, frameCapacity: 1024)!
            var error: NSError? = nil
            let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            converter.convert(to: outBuffer, error: &error, withInputFrom: inputBlock)
            if let error { print("Audio convert error: \(error)"); return }
            self.onBuffer?(outBuffer, desired, time)
        }
    }

    func start() throws { try engine.start() }
    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }
}
