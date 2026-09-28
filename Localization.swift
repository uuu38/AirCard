import Foundation

// MARK: - Localization Helpers
//
// All user-facing strings use their English text as the lookup key.
// Translations live in `Localizations/<lang>.lproj/Localizable.strings` and are
// copied into the app bundle's Resources directory by build.sh. When a key is
// missing from the active language, Foundation falls back to the key itself
// (English), so untranslated strings always degrade gracefully.

/// Returns the localized string for an English key from Localizable.strings.
func L(_ key: String) -> String {
    Bundle.main.localizedString(forKey: key, value: nil, table: nil)
}

/// Localized printf-style formatting, e.g. `Lf("Card #%d", index + 1)`.
/// The format placeholders (%@, %d, ...) are part of the key and must be kept
/// intact (and in the same order) in every translation.
func Lf(_ key: String, _ args: CVarArg...) -> String {
    String(format: L(key), arguments: args)
}

// MARK: - Backend Message Localization
//
// The Python backend (aircard_backend.py) reports progress as JSON lines that
// carry a semantic `code` plus a `params` dictionary, alongside the legacy
// English `message` field. This mapper turns codes into localized text so the
// status bar and activity log follow the system language. Unknown codes fall
// back to the raw `message`, keeping older backends fully compatible.

enum BackendMessage {
    /// Maps a backend message code to its English format-string key and the
    /// ordered list of parameter names consumed by that template.
    private static let catalog: [String: (key: String, params: [String])] = [
        // Card skin flashing (cmd_flash)
        "prepare_artwork_failed":   ("Failed to prepare card artwork", []),
        "writing_artwork_batch":    ("Writing %d artwork files (fast batch)...", ["count"]),
        "invalidating_cache":       ("Invalidating cache (%@)...", ["ext"]),
        "cache_clear_failed":       ("Could not clear Wallet cache (%@); card was not reported as updated.", ["ext"]),
        "card_update_failed":       ("Failed to update %@...", ["card"]),
        "card_update_success":      ("Successfully updated %@...", ["card"]),
        // Passcode theme flashing (cmd_flash_passthm)
        "passthm_flash_start":      ("Flashing passcode theme '%@' (%d assets)...", ["name", "count"]),
        "passthm_writing":          ("Writing %@ (%d/%d)...", ["leaf", "step", "total"]),
        "passthm_flashing_dir":     ("Flashing %d asset(s) into %@...", ["count", "dir"]),
        "passthm_batch_fallback":   ("Batch write notice for %@, falling back to file-by-file write...", ["dir"]),
        "passthm_writing_fallback": ("[Fallback] Writing %@ (%d/%d)...", ["leaf", "step", "total"]),
        "passthm_write_failed":     ("Could not write %d file(s) in %@: %@", ["count", "dir", "files"]),
        "passthm_applied":          ("Passcode theme '%@' successfully applied! Lock your iPhone to check.", ["name"]),
    ]

    /// Renders a backend JSON line into a localized display string.
    /// Prefers the semantic `code` + `params` payload and falls back to the
    /// legacy English `message` field when the code is absent or unknown.
    static func localized(from json: [String: Any]) -> String? {
        if let code = json["code"] as? String, let entry = catalog[code] {
            let params = json["params"] as? [String: Any] ?? [:]
            let args: [CVarArg] = entry.params.map { name in
                switch params[name] {
                case let number as NSNumber: return number.intValue
                case let string as String: return string
                default: return ""
                }
            }
            return String(format: L(entry.key), arguments: args)
        }
        return json["message"] as? String
    }
}
