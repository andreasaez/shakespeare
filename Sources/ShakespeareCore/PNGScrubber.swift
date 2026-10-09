import Foundation

/// Removes every non-essential chunk (EXIF, text, timestamps, profiles) from a PNG, so an
/// exported card carries pixels and nothing else: no author, device, time or location.
public enum PNGScrubber {
    /// Chunks needed to decode and display the image correctly.
    static let keep: Set<String> = ["IHDR", "PLTE", "tRNS", "IDAT", "IEND", "sRGB"]
    private static let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

    /// Returns the scrubbed PNG, or nil if `data` isn't a well-formed PNG (fail closed).
    public static func scrub(_ data: Data) -> Data? {
        let bytes = [UInt8](data)
        guard bytes.count >= 8, Array(bytes[0..<8]) == signature else { return nil }
        var output = Array(bytes[0..<8])
        var index = 8
        var sawHeader = false, sawEnd = false
        while index + 12 <= bytes.count {
            let length = Int(bytes[index]) << 24 | Int(bytes[index + 1]) << 16 | Int(bytes[index + 2]) << 8 | Int(bytes[index + 3])
            let end = index + 12 + length   // length + type + data + CRC
            guard length >= 0, end <= bytes.count else { return nil }
            let type = String(decoding: bytes[(index + 4)..<(index + 8)], as: UTF8.self)
            if keep.contains(type) { output.append(contentsOf: bytes[index..<end]) }
            if type == "IHDR" { sawHeader = true }
            index = end
            if type == "IEND" { sawEnd = true; break }
        }
        return sawHeader && sawEnd ? Data(output) : nil
    }
}
