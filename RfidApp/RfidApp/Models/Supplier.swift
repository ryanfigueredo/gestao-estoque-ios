import Foundation

struct Supplier: Codable, Identifiable {
    let id: String
    let name: String?
    let document: String?
    let email: String?
    let phone: String?

    enum CodingKeys: String, CodingKey {
        case id, name, document, email, phone
    }
}
