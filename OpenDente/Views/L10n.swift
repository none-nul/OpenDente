import SwiftUI

enum L10n {
    /// Resolve a finished English string against Localizable.strings.
    ///
    /// Dynamic text such as "85.0%" must not go through `LocalizedStringKey`:
    /// a trailing percent sign is a format specifier. Lookup misses return the
    /// original string, so measurements stay unchanged.
    static func text(_ key: String) -> Text {
        Text(verbatim: Bundle.main.localizedString(forKey: key, value: key, table: nil))
    }
}
