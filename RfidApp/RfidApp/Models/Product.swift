import Foundation

struct Product: Codable, Identifiable {
    let id: String
    let name: String
    let sku: String?
    let price: Double?
    let cost: Double?
    let stock: Double?
    let minStock: Double?
    let unit: String?
    let category: String?
    let categoryId: String?
    let description: String?
    let rfidTag: String?
    let barcode: String?
    let tenantId: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, sku, unit, barcode, description
        case minStock = "min_stock"
        case categoryId = "category_id"
        case rfidTag = "rfid_tag"
        case tenantId = "tenant_id"
        case createdAt = "created_at"
        case category, price, cost, stock
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        sku = try? c.decodeIfPresent(String.self, forKey: .sku)
        unit = try? c.decodeIfPresent(String.self, forKey: .unit)
        description = try? c.decodeIfPresent(String.self, forKey: .description)
        category = try? c.decodeIfPresent(String.self, forKey: .category)
        categoryId = try? c.decodeIfPresent(String.self, forKey: .categoryId)
        rfidTag = try? c.decodeIfPresent(String.self, forKey: .rfidTag)
        barcode = try? c.decodeIfPresent(String.self, forKey: .barcode)
        tenantId = try? c.decodeIfPresent(String.self, forKey: .tenantId)
        createdAt = try? c.decodeIfPresent(String.self, forKey: .createdAt)
        price = Self.decodeDouble(c, forKey: .price)
        cost = Self.decodeDouble(c, forKey: .cost)
        stock = Self.decodeDouble(c, forKey: .stock)
        minStock = Self.decodeDouble(c, forKey: .minStock)
    }

    private static func decodeDouble(_ c: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Double? {
        if let v = try? c.decodeIfPresent(Double.self, forKey: key) { return v }
        if let v = try? c.decodeIfPresent(Int.self, forKey: key) { return Double(v) }
        if let s = try? c.decodeIfPresent(String.self, forKey: key), let v = Double(s) { return v }
        return nil
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(sku, forKey: .sku)
        try c.encodeIfPresent(price, forKey: .price)
        try c.encodeIfPresent(cost, forKey: .cost)
        try c.encodeIfPresent(stock, forKey: .stock)
        try c.encodeIfPresent(minStock, forKey: .minStock)
        try c.encodeIfPresent(unit, forKey: .unit)
        try c.encodeIfPresent(category, forKey: .category)
        try c.encodeIfPresent(categoryId, forKey: .categoryId)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(rfidTag, forKey: .rfidTag)
        try c.encodeIfPresent(barcode, forKey: .barcode)
        try c.encodeIfPresent(tenantId, forKey: .tenantId)
        try c.encodeIfPresent(createdAt, forKey: .createdAt)
    }
}
