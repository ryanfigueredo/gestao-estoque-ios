import Foundation

struct Customer: Codable, Identifiable {
    let id: String
    let name: String?
    let document: String?
    let documentType: String?
    let email: String?
    let phone: String?

    enum CodingKeys: String, CodingKey {
        case id, name, document, email, phone
        case documentType = "document_type"
    }
}
