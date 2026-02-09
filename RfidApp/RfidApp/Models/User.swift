import Foundation

struct User: Codable {
    let id: String
    let email: String
    let name: String
    let role: String
    let tenantId: String?
    let tenantName: String?

    enum CodingKeys: String, CodingKey {
        case id, email, name, role
        case tenantId = "tenant_id"
        case tenantName = "tenant_name"
    }
}

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct LoginResponse: Decodable {
    let success: Bool
    let user: User
    let token: String?
    let error: String?
}
