import Foundation

struct NFe: Codable, Identifiable {
    let id: String
    let saleId: String?
    let number: String?
    let accessKey: String?
    let status: String?
    let total: Double?
    let customerName: String?
    let customerDocument: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, number, accessKey, status, total, createdAt
        case saleId = "sale_id"
        case customerName = "customer_name"
        case customerDocument = "customer_document"
    }
}
