import Foundation
import Security

/// What an application must find again next time it is opened, kept where the phone keeps a secret.
///
/// The keychain rather than a file the application writes: what is in it is encrypted at rest by the
/// system, is reachable only by this application, and is not readable off a backup the way a file in the
/// application's own directory is. It is not readable until the device has been unlocked once since it
/// was started, which is what a preference wants — reachable in the background, never before the reader
/// has proved the phone is theirs.
enum VarnPreferences {
    private static let service = "dev.varn.gui.preferences"

    static func set(_ name: String, _ value: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: name,
        ]

        let written: [String: Any] = [
            kSecValueData as String: value,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let updated = SecItemUpdate(query as CFDictionary, written as CFDictionary)

        if updated == errSecSuccess {
            return
        }

        guard updated == errSecItemNotFound else {
            throw VarnPreferencesError.refused(updated)
        }

        let added = SecItemAdd(query.merging(written) { current, _ in current } as CFDictionary, nil)

        guard added == errSecSuccess else {
            throw VarnPreferencesError.refused(added)
        }
    }

    static func get(_ name: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: name,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var found: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &found)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw VarnPreferencesError.refused(status)
        }

        return found as? Data
    }

    static func remove(_ name: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: name,
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw VarnPreferencesError.refused(status)
        }
    }

    static func clear() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw VarnPreferencesError.refused(status)
        }
    }

    static func names() throws -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]

        var found: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &found)

        if status == errSecItemNotFound {
            return []
        }

        guard status == errSecSuccess else {
            throw VarnPreferencesError.refused(status)
        }

        let items = found as? [[String: Any]] ?? []

        return items.compactMap { $0[kSecAttrAccount as String] as? String }.sorted()
    }
}

enum VarnPreferencesError: Error, CustomStringConvertible {
    case refused(OSStatus)

    var description: String {
        switch self {
        case .refused(let status):
            let said = SecCopyErrorMessageString(status, nil) as String? ?? "no reason given"
            return "the keychain refused it: \(said)"
        }
    }
}
