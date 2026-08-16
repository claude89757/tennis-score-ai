import Foundation

enum WAVEncoder {
  static func encodePCM16Mono(_ pcmData: Data, sampleRate: UInt32 = 16_000) -> Data {
    let channels: UInt16 = 1
    let bitsPerSample: UInt16 = 16
    let bytesPerSample = UInt32(bitsPerSample / 8)
    let byteRate = sampleRate * UInt32(channels) * bytesPerSample
    let blockAlign = channels * (bitsPerSample / 8)
    let payloadSize = UInt32(pcmData.count)

    var output = Data()
    output.appendASCII("RIFF")
    output.appendLittleEndian(UInt32(36) + payloadSize)
    output.appendASCII("WAVE")
    output.appendASCII("fmt ")
    output.appendLittleEndian(UInt32(16))
    output.appendLittleEndian(UInt16(1))
    output.appendLittleEndian(channels)
    output.appendLittleEndian(sampleRate)
    output.appendLittleEndian(byteRate)
    output.appendLittleEndian(blockAlign)
    output.appendLittleEndian(bitsPerSample)
    output.appendASCII("data")
    output.appendLittleEndian(payloadSize)
    output.append(pcmData)
    return output
  }
}

extension Data {
  fileprivate mutating func appendASCII(_ value: String) {
    append(contentsOf: value.utf8)
  }

  fileprivate mutating func appendLittleEndian<Value: FixedWidthInteger>(_ value: Value) {
    var littleEndian = value.littleEndian
    Swift.withUnsafeBytes(of: &littleEndian) { bytes in
      append(contentsOf: bytes)
    }
  }
}
