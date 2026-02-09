import Foundation

struct Sale: Codable, Identifiable {
    let id: String
    let customerId: String?
    let customerName: String?
    let customerDocument: String?
    let subtotal: Double?
    let discount: Double?
    let total: Double?
    let paymentMethod: String?
    let status: String?
    let nfeNumber: String?
    let tenantId: String?
    let createdAt: String?
    let items: [SaleItem]?

    enum CodingKeys: String, CodingKey {
        case id, subtotal, discount, total, status, items, tenantId
        case customerId = "customer_id"
        case customerName = "customer_name"
        case customerDocument = "customer_document"
        case paymentMethod = "payment_method"
        case nfeNumber = "nfe_number"
        case createdAt = "created_at"
    }

    init(id: String, customerId: String?, customerName: String?, customerDocument: String?,
         subtotal: Double?, discount: Double?, total: Double?, paymentMethod: String?,
         status: String?, nfeNumber: String?, tenantId: String?, createdAt: String?, items: [SaleItem]?) {
        self.id = id
        self.customerId = customerId
        self.customerName = customerName
        self.customerDocument = customerDocument
        self.subtotal = subtotal
        self.discount = discount
        self.total = total
        self.paymentMethod = paymentMethod
        self.status = status
        self.nfeNumber = nfeNumber
        self.tenantId = tenantId
        self.createdAt = createdAt
        self.items = items
    }

    static func fromDailyItem(id: String, customerName: String?, total: Double?, paymentMethod: String?, createdAt: String?) -> Sale {
        Sale(
            id: id,
            customerId: nil,
            customerName: customerName,
            customerDocument: nil,
            subtotal: nil,
            discount: nil,
            total: total,
            paymentMethod: paymentMethod,
            status: "completed",
            nfeNumber: nil,
            tenantId: nil,
            createdAt: createdAt,
            items: nil
        )
    }
}

struct SaleItem: Codable {
    let id: String
    let productId: String?
    let quantity: Double?
    let unitPrice: Double?
    let subtotal: Double?

    enum CodingKeys: String, CodingKey {
        case id, quantity, subtotal
        case productId = "product_id"
        case unitPrice = "unit_price"
    }
}

struct SaleDetail: Codable {
    let id: String
    let customerId: String?
    let customerName: String?
    let customerDocument: String?
    let subtotal: Double?
    let discount: Double?
    let total: Double?
    let paymentMethod: String?
    let status: String?
    let nfeNumber: String?
    let shouldEmitNfe: Bool?
    let tenantId: String?
    let createdAt: String?
    let items: [SaleItemDetail]?

    enum CodingKeys: String, CodingKey {
        case id, subtotal, discount, total, status, items, tenantId
        case customerId = "customer_id"
        case customerName = "customer_name"
        case customerDocument = "customer_document"
        case paymentMethod = "payment_method"
        case nfeNumber = "nfe_number"
        case shouldEmitNfe = "should_emit_nfe"
        case createdAt = "created_at"
    }
}

struct SaleItemDetail: Codable {
    let id: String
    let productId: String?
    let quantity: Double?
    let unitPrice: Double?
    let subtotal: Double?
    let product: SaleItemProductInfo?

    enum CodingKeys: String, CodingKey {
        case id, quantity, subtotal, product
        case productId = "product_id"
        case unitPrice = "unit_price"
    }
}

struct SaleItemProductInfo: Codable {
    let id: String?
    let name: String?
    let sku: String?
    let unit: String?
    let price: Double?
    let cost: Double?
}
