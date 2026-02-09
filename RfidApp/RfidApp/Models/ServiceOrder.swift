import Foundation

struct ServiceOrder: Codable, Identifiable {
    let id: String
    let number: String?
    let customerName: String?
    let status: String?
    let total: Double?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, number, total, status
        case customerName = "customer_name"
        case createdAt = "created_at"
    }
}

struct ServiceOrderDetail: Codable {
    let id: String
    let number: String?
    let customerName: String?
    let vehicleInfo: String?
    let licensePlate: String?
    let description: String?
    let status: String?
    let subtotal: Double?
    let discount: Double?
    let total: Double?
    let createdAt: String?
    let items: [ServiceOrderItemDetail]?
    let mechanics: [ServiceOrderMechanicDetail]?

    enum CodingKeys: String, CodingKey {
        case id, number, status, subtotal, discount, total, items, mechanics, description
        case customerName = "customer_name"
        case vehicleInfo = "vehicle_info"
        case licensePlate = "license_plate"
        case createdAt = "created_at"
    }
}

struct ServiceOrderItemDetail: Codable {
    let id: String
    let productId: String?
    let productName: String?
    let quantity: Double?
    let unitPrice: Double?
    let subtotal: Double?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, quantity, subtotal
        case productId = "product_id"
        case productName = "product_name"
        case unitPrice = "unit_price"
        case createdAt = "created_at"
    }
}

struct ServiceOrderMechanicDetail: Codable {
    let id: String
    let mechanicId: String?
    let mechanicName: String?
    let functionDescription: String?
    let value: Double?

    enum CodingKeys: String, CodingKey {
        case id, value
        case mechanicId = "mechanic_id"
        case mechanicName = "mechanic_name"
        case functionDescription = "function_description"
    }
}

struct Mechanic: Codable, Identifiable {
    let id: String
    let name: String
    let phone: String?
    let email: String?
    let status: String?
}

struct ServiceOrderCreateResponse: Codable {
    let id: String
    let number: String?
    let success: Bool?
}

struct ServiceOrderMechanicPayload {
    let mechanicId: String
    let functionDescription: String
    let value: Double
}

struct ServiceOrderItemPayload {
    let productId: String
    let quantity: Double
    let unitPrice: Double
    let subtotal: Double
}
