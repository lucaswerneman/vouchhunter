import Foundation
import Security
import HuntCore

enum APIError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let m) = self { return m }; return nil }
}
enum Keychain {
    private static let service = "se.vouchhunter.session"
    static func read() -> String? {
        let q: [String:Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:"session",kSecReturnData as String:true,kSecMatchLimit as String:kSecMatchLimitOne]
        var value: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary,&value) == errSecSuccess, let data = value as? Data else { return nil }
        return String(data:data,encoding:.utf8)
    }
    static func save(_ value: String) throws {
        let q: [String:Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:"session"]
        let attributes: [String:Any] = [kSecValueData as String:Data(value.utf8),kSecAttrAccessible as String:kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        var status=SecItemUpdate(q as CFDictionary,attributes as CFDictionary)
        if status == errSecItemNotFound { status=SecItemAdd(q.merging(attributes){_,new in new} as CFDictionary,nil) }
        guard status == errSecSuccess else { throw APIError.message("Kunde inte spara inloggningen säkert.") }
    }
    static func clear() { SecItemDelete([kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service] as CFDictionary) }
}
@MainActor final class API {
    static let shared = API()
    let baseURL: URL
    init() {
        let raw=Bundle.main.object(forInfoDictionaryKey:"API_BASE_URL") as? String ?? ""
        baseURL=URL(string:raw) ?? URL(string:"https://configuration-required.invalid")!
    }
    func request<T: Decodable>(_ path: String, body: [String:Any]? = nil) async throws -> T {
        guard baseURL.host != "configuration-required.invalid" else { throw APIError.message("Serveradressen behöver konfigureras för den här appversionen.") }
        var request = URLRequest(url:baseURL.appendingPathComponent("api"+path))
        request.timeoutInterval=20
        if let token=Keychain.read() { request.setValue("Bearer "+token,forHTTPHeaderField:"Authorization") }
        if let body { request.httpMethod="POST";request.setValue("application/json",forHTTPHeaderField:"Content-Type");request.httpBody=try JSONSerialization.data(withJSONObject:body) }
        let (data,response)=try await URLSession.shared.data(for:request)
        guard let http=response as? HTTPURLResponse else { throw APIError.message("Servern svarade inte.") }
        guard (200..<300).contains(http.statusCode) else {
            let message=(try? JSONSerialization.jsonObject(with:data) as? [String:String])?["error"] ?? "Något gick fel. Försök igen."
            throw APIError.message(message)
        }
        return try JSONDecoder().decode(T.self,from:data)
    }
}
