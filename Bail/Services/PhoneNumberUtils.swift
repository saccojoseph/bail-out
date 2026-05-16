import Foundation

enum PhoneNumberUtils {
    /// Strips a phone number down to digits only, prefixing "1" for US numbers
    /// that don't already have a country code. This gives us a consistent key
    /// for matching contacts across devices.
    ///
    /// Examples:
    ///   "(203) 555-1234"  → "12035551234"
    ///   "+1 203-555-1234" → "12035551234"
    ///   "203.555.1234"    → "12035551234"
    static func normalize(_ raw: String) -> String {
        let digits = raw.filter { $0.isWholeNumber }
        guard !digits.isEmpty else { return "" }

        // If it already starts with country code "1" and is 11 digits, keep it
        if digits.count == 11 && digits.hasPrefix("1") {
            return digits
        }
        // US 10-digit number — prepend "1"
        if digits.count == 10 {
            return "1" + digits
        }
        // International or other formats — return digits as-is
        return digits
    }
}
