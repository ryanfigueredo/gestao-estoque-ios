import Foundation

struct StockMovement: Codable, Identifiable {
    let id: String
    let productId: String?
    let type: String?
    let quantity: Double?
    let notes: String?
    let createdAt: String?
    let product: ProductRef?

    enum CodingKeys: String, CodingKey {
        case id, type, quantity, notes, product
        case productId = "product_id"
        case createdAt = "created_at"
    }
}

struct ProductRef: Codable {
    let id: String
    let name: String?
    let unit: String?
}
