import Foundation

/// Checked-in builds intentionally contain no credential. GitHub Actions replaces this
/// file only inside the ephemeral runner before producing the private-use SideStore IPA.
enum EmbeddedMeteoblueSecret {
    private static let encoded: [UInt8] = []
    private static let mask: [UInt8] = []

    static var apiKey: String? {
        guard !encoded.isEmpty, encoded.count == mask.count else { return nil }
        let bytes = zip(encoded, mask).map { pair in pair.0 ^ pair.1 }
        return String(bytes: bytes, encoding: .utf8)
    }
}
