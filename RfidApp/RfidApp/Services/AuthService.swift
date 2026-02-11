import Foundation
import Security
import Combine

final class AuthService: ObservableObject {
    static let shared = AuthService()

    private let keychainTokenKey = "com.dmtn.rfid.authToken"
    private let keychainUserKey = "com.dmtn.rfid.user"
    private let keychainSavedEmailKey = "com.dmtn.rfid.savedEmail"
    private let keychainSavedPasswordKey = "com.dmtn.rfid.savedPassword"
    private let savePasswordKey = "com.dmtn.rfid.savePassword"
    private let api = ApiClient.shared

    var savedEmail: String? { getKeychain(key: keychainSavedEmailKey) }
    var savedPassword: String? { getKeychain(key: keychainSavedPasswordKey) }
    var shouldSavePassword: Bool {
        get { UserDefaults.standard.bool(forKey: savePasswordKey) }
        set { UserDefaults.standard.set(newValue, forKey: savePasswordKey) }
    }

    func saveCredentials(email: String, password: String) {
        setKeychain(key: keychainSavedEmailKey, value: email)
        setKeychain(key: keychainSavedPasswordKey, value: password)
    }

    func clearSavedCredentials() {
        deleteKeychain(key: keychainSavedEmailKey)
        deleteKeychain(key: keychainSavedPasswordKey)
    }

    @Published private(set) var currentUser: User?
    @Published private(set) var isLoggedIn: Bool = false

    private init() {
        loadSession()
    }

    func loadSession() {
        if let token = getKeychain(key: keychainTokenKey), !token.isEmpty {
            api.setAuthToken(token)
            currentUser = loadUserFromKeychain()
            if currentUser?.role == "master" {
                if let tenantId = UserDefaults.standard.string(forKey: "selected_tenant_id"), !tenantId.isEmpty {
                    api.setTenantId(tenantId)
                }
            }
            isLoggedIn = true
        } else {
            api.setAuthToken(nil)
            api.setTenantId(nil)
            currentUser = nil
            isLoggedIn = false
        }
    }

    func login(email: String, password: String) async throws {
        let (user, token) = try await api.login(email: email, password: password)
        setKeychain(key: keychainTokenKey, value: token)
        saveUserToKeychain(user)
        api.setAuthToken(token)
        if let tid = user.tenantId, !tid.isEmpty {
            api.setTenantId(tid)
        } else {
            api.setTenantId(nil)
        }
        await MainActor.run {
            currentUser = user
            isLoggedIn = true
        }
    }

    func logout() {
        deleteKeychain(key: keychainTokenKey)
        deleteKeychain(key: keychainUserKey)
        UserDefaults.standard.removeObject(forKey: "selected_tenant_id")
        UserDefaults.standard.removeObject(forKey: "tenant_name")
        api.setAuthToken(nil)
        api.setTenantId(nil)
        TenantBrandingService.shared.reset()
        currentUser = nil
        isLoggedIn = false
    }

    private func loadUserFromKeychain() -> User? {
        guard let data = getKeychainData(key: keychainUserKey),
              let user = try? JSONDecoder().decode(User.self, from: data) else { return nil }
        return user
    }

    private func saveUserToKeychain(_ user: User) {
        if let data = try? JSONEncoder().encode(user) {
            setKeychainData(key: keychainUserKey, value: data)
        }
    }

    // MARK: - Keychain helpers

    private func setKeychain(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        deleteKeychain(key: key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private func getKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func setKeychainData(key: String, value: Data) {
        deleteKeychain(key: key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: value
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private func getKeychainData(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    private func deleteKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
