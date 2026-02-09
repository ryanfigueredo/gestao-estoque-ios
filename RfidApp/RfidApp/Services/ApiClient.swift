import Foundation

enum ApiError: LocalizedError {
    case invalidURL
    case noData
    case serverError(String)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "URL inválida"
        case .noData: return "Resposta vazia"
        case .serverError(let msg): return msg
        case .decodingError: return "Erro ao interpretar resposta"
        }
    }
}

final class ApiClient {
    static let shared = ApiClient()

    private(set) var authToken: String?
    private(set) var tenantId: String?

    var baseURL: String { AppConfig.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) }

    func setAuthToken(_ token: String?) { authToken = token }
    func setTenantId(_ id: String?) { tenantId = id }

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = AppConfig.defaultTimeout
        config.timeoutIntervalForResource = AppConfig.defaultTimeout
        return URLSession(configuration: config)
    }()

    private func makeRequest(path: String, method: String = "GET", body: Data? = nil) throws -> URLRequest {
        let pathTrimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let urlString = "\(baseURL)/\(pathTrimmed)"
        guard let url = URL(string: urlString) else {
            throw ApiError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "x-mobile-app")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let tid = tenantId, !tid.isEmpty {
            request.setValue(tid, forHTTPHeaderField: "x-tenant-id")
        }
        request.httpBody = body
        return request
    }

    private func get<T: Decodable>(path: String) async throws -> T {
        let request = try makeRequest(path: path, method: "GET")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ApiError.noData }
        guard http.statusCode == 200 else {
            let msg = (try? JSONDecoder().decode([String: String].self, from: data))?["error"] ?? "Erro \(http.statusCode)"
            throw ApiError.serverError(msg)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func request(path: String, method: String, body: Data? = nil) async throws -> Data {
        let request = try makeRequest(path: path, method: method, body: body)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ApiError.noData }
        guard (200...299).contains(http.statusCode) else {
            let msg = (try? JSONDecoder().decode([String: String].self, from: data))?["error"] ?? "Erro \(http.statusCode)"
            throw ApiError.serverError(msg)
        }
        return data
    }

    func login(email: String, password: String) async throws -> (user: User, token: String) {
        let payload = LoginRequest(email: email, password: password)
        let data = try JSONEncoder().encode(payload)
        let request = try makeRequest(path: "api/auth/login", method: "POST", body: data)

        let (responseData, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ApiError.noData }

        if http.statusCode != 200 {
            let message = (try? JSONDecoder().decode([String: String].self, from: responseData))?["error"] ?? "Erro ao fazer login"
            throw ApiError.serverError(message)
        }

        let decoded = try JSONDecoder().decode(LoginResponse.self, from: responseData)
        guard decoded.success, let token = decoded.token else {
            throw ApiError.serverError(decoded.error ?? "Login falhou")
        }
        return (decoded.user, token)
    }

    func getProducts() async throws -> [Product] {
        try await get(path: "api/products")
    }

    func getProductByRfid(tag: String) async throws -> Product {
        let escaped = tag.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? tag
        return try await get(path: "api/products/rfid/\(escaped)")
    }

    func updateProductRfidTag(product: Product, rfidTag: String) async throws {
        let escaped = product.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? product.id
        var payload: [String: Any] = [
            "name": product.name,
            "sku": product.sku ?? "",
            "rfidTag": rfidTag.trimmingCharacters(in: .whitespacesAndNewlines),
            "price": product.price ?? 0,
            "cost": product.cost ?? 0,
            "stock": product.stock ?? 0,
            "minStock": product.minStock ?? 0,
            "category": product.category ?? "",
            "unit": product.unit ?? ""
        ]
        payload["description"] = product.description ?? NSNull()
        payload["barcode"] = product.barcode ?? NSNull()
        let data = try JSONSerialization.data(withJSONObject: payload)
        _ = try await request(path: "api/products/\(escaped)", method: "PUT", body: data)
    }

    func getSales() async throws -> [Sale] {
        try await get(path: "api/sales")
    }

    func getSale(id: String) async throws -> SaleDetail {
        let escaped = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        return try await get(path: "api/sales/\(escaped)")
    }

    func postCreateSale(payload: CreateSalePayload) async throws -> CreateSaleResponse {
        let data = try JSONEncoder().encode(payload)
        let responseData = try await request(path: "api/sales", method: "POST", body: data)
        return try JSONDecoder().decode(CreateSaleResponse.self, from: responseData)
    }

    func getStockMovements() async throws -> [StockMovement] {
        try await get(path: "api/stock-movements")
    }

    func getDailyReport(date: String? = nil) async throws -> DailyReportResponse {
        let path = date.map { "api/daily-report?date=\($0)" } ?? "api/daily-report"
        return try await get(path: path)
    }

    func getNFe() async throws -> [NFe] {
        try await get(path: "api/nfe")
    }

    func postNfeGenerate(saleId: String) async throws -> NFeGenerateResponse {
        let payload = ["saleId": saleId]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let responseData = try await request(path: "api/nfe/generate", method: "POST", body: data)
        return try JSONDecoder().decode(NFeGenerateResponse.self, from: responseData)
    }

    func postFiscalReceiptPdf(saleId: String) async throws -> FiscalReceiptResponse {
        let payload = ["saleId": saleId]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let responseData = try await request(path: "api/fiscal-receipt/pdf", method: "POST", body: data)
        return try JSONDecoder().decode(FiscalReceiptResponse.self, from: responseData)
    }

    func getTenantMe() async throws -> TenantMeResponse {
        try await get(path: "api/tenant/me")
    }

    func getBotStatus() async throws -> BotStatusResponse {
        try await get(path: "api/bot/status")
    }

    func getBotConversations() async throws -> [BotConversation] {
        let res: BotConversationsResponse = try await get(path: "api/bot/inbox/conversations")
        return res.conversations ?? []
    }

    func getBotMessages(phone: String) async throws -> [BotMessage] {
        let escaped = phone.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? phone
        let res: BotMessagesResponse = try await get(path: "api/bot/inbox/conversations/\(escaped)")
        return res.messages ?? []
    }

    func getBotMedia(messageId: String) async throws -> Data {
        let escaped = messageId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? messageId
        return try await request(path: "api/bot/inbox/media?message_id=\(escaped)", method: "GET")
    }

    func sendBotMessage(phone: String, body: String, attendantName: String?) async throws {
        let escaped = phone.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? phone
        var payload: [String: Any] = ["body": body]
        if let name = attendantName, !name.isEmpty {
            payload["attendant_name"] = name
        }
        let data = try JSONSerialization.data(withJSONObject: payload)
        _ = try await request(path: "api/bot/inbox/conversations/\(escaped)", method: "POST", body: data)
    }

    func concluirAtendimento(phone: String) async throws {
        let escaped = phone.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? phone
        _ = try await request(path: "api/bot/inbox/conversations/\(escaped)/concluir", method: "POST", body: "{}".data(using: .utf8))
    }

    func createSupportTicket(subject: String, description: String, category: String = "geral") async throws -> SupportTicketCreateResponse {
        var payload: [String: Any] = ["subject": subject, "description": description]
        if !category.isEmpty { payload["category"] = category }
        let data = try JSONSerialization.data(withJSONObject: payload)
        let response = try await request(path: "api/support-tickets", method: "POST", body: data)
        return try JSONDecoder().decode(SupportTicketCreateResponse.self, from: response)
    }

    func getSupportTickets() async throws -> [SupportTicket] {
        let res: SupportTicketsResponse = try await get(path: "api/support-tickets")
        return res.tickets ?? []
    }

    func getBotOrders() async throws -> [BotOrder] {
        let res: BotOrdersResponse = try await get(path: "api/bot/orders")
        return res.orders ?? []
    }

    func updateOrderStatus(orderId: String, status: String) async throws {
        let escaped = orderId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? orderId
        let payload = ["status": status]
        let data = try JSONSerialization.data(withJSONObject: payload)
        _ = try await request(path: "api/bot/orders/\(escaped)/status", method: "PATCH", body: data)
    }

    func createBotOrder(customerPhone: String, items: String, customerName: String?, notes: String?, sendWhatsApp: Bool = true) async throws -> (id: String, orderNumber: String) {
        var payload: [String: Any] = [
            "customer_phone": customerPhone,
            "items": items,
            "send_whatsapp": sendWhatsApp,
        ]
        if let name = customerName, !name.isEmpty { payload["customer_name"] = name }
        if let n = notes, !n.isEmpty { payload["notes"] = n }
        let data = try JSONSerialization.data(withJSONObject: payload)
        let response = try await request(path: "api/bot/orders", method: "POST", body: data)
        guard let json = try JSONSerialization.jsonObject(with: response) as? [String: Any],
              let order = json["order"] as? [String: Any],
              let id = order["id"] as? String,
              let orderNumber = order["order_number"] as? String else {
            throw ApiError.noData
        }
        return (id, orderNumber)
    }

    func getCustomers() async throws -> [Customer] {
        try await get(path: "api/customers")
    }

    func createCustomer(name: String, document: String, phone: String? = nil, email: String? = nil) async throws -> Customer {
        var payload: [String: Any] = ["name": name, "document": document]
        if let p = phone, !p.isEmpty { payload["phone"] = p }
        if let e = email, !e.isEmpty { payload["email"] = e }
        let data = try JSONSerialization.data(withJSONObject: payload)
        let response = try await request(path: "api/customers", method: "POST", body: data)
        let decoded = try JSONDecoder().decode(CustomerCreateResponse.self, from: response)
        guard let c = decoded.customer else { throw ApiError.noData }
        return c
    }

    func getSuppliers() async throws -> [Supplier] {
        try await get(path: "api/suppliers")
    }

    func getCategories() async throws -> [Category] {
        try await get(path: "api/categories")
    }

    func createCategory(name: String) async throws -> Category {
        let payload = ["name": name]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let responseData = try await request(path: "api/categories", method: "POST", body: data)
        let decoded = try JSONDecoder().decode(CategoryCreateResponse.self, from: responseData)
        return decoded.category
    }

    func updateCategory(id: String, name: String) async throws {
        let payload = ["name": name]
        let data = try JSONSerialization.data(withJSONObject: payload)
        _ = try await request(path: "api/categories/\(id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id)", method: "PUT", body: data)
    }

    func deleteCategory(id: String) async throws {
        let escaped = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        _ = try await request(path: "api/categories/\(escaped)", method: "DELETE")
    }

    func getPromotions(activeOnly: Bool = false) async throws -> [Promotion] {
        let path = "api/promotions?active=\(activeOnly ? "true" : "false")"
        return try await get(path: path)
    }

    func createPromotion(productId: String, promotionalPrice: Double, startDate: String, endDate: String, description: String?) async throws {
        var payload: [String: Any] = [
            "productId": productId,
            "promotionalPrice": promotionalPrice,
            "startDate": startDate,
            "endDate": endDate,
        ]
        if let d = description, !d.isEmpty { payload["description"] = d }
        let data = try JSONSerialization.data(withJSONObject: payload)
        _ = try await request(path: "api/promotions", method: "POST", body: data)
    }

    func updatePromotion(id: String, promotionalPrice: Double, startDate: String, endDate: String, description: String?) async throws {
        var payload: [String: Any] = [
            "promotionalPrice": promotionalPrice,
            "startDate": startDate,
            "endDate": endDate,
        ]
        if let d = description { payload["description"] = d }
        let data = try JSONSerialization.data(withJSONObject: payload)
        let escaped = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        _ = try await request(path: "api/promotions/\(escaped)", method: "PUT", body: data)
    }

    func deletePromotion(id: String) async throws {
        let escaped = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        _ = try await request(path: "api/promotions/\(escaped)", method: "DELETE")
    }

    func sharePromotionsWhatsApp(mode: String, phones: [String]? = nil) async throws -> ShareWhatsAppResponse {
        var payload: [String: Any] = ["mode": mode]
        if mode == "specific", let p = phones { payload["phones"] = p }
        let data = try JSONSerialization.data(withJSONObject: payload)
        let responseData = try await request(path: "api/promotions/share-whatsapp", method: "POST", body: data)
        return try JSONDecoder().decode(ShareWhatsAppResponse.self, from: responseData)
    }

    func getReportsSales(startDate: String, endDate: String, category: String? = nil) async throws -> ReportsSalesResponse {
        var path = "api/reports/sales?startDate=\(startDate)&endDate=\(endDate)"
        if let c = category, !c.isEmpty { path += "&category=\(c.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? c)" }
        return try await get(path: path)
    }

    func getServiceOrders() async throws -> [ServiceOrder] {
        try await get(path: "api/service-orders")
    }

    func getServiceOrder(id: String) async throws -> ServiceOrderDetail {
        let escaped = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        return try await get(path: "api/service-orders/\(escaped)")
    }

    func getMechanics() async throws -> [Mechanic] {
        try await get(path: "api/mechanics")
    }

    func createServiceOrder(customerName: String, vehicleInfo: String?, licensePlate: String?, description: String?, items: [[String: Any]] = []) async throws -> ServiceOrderCreateResponse {
        var payload: [String: Any] = ["customerName": customerName, "items": items]
        if let v = vehicleInfo { payload["vehicleInfo"] = v }
        if let p = licensePlate { payload["licensePlate"] = p }
        if let d = description { payload["description"] = d }
        let data = try JSONSerialization.data(withJSONObject: payload)
        let response = try await request(path: "api/service-orders", method: "POST", body: data)
        return try JSONDecoder().decode(ServiceOrderCreateResponse.self, from: response)
    }

    func updateServiceOrder(id: String, customerName: String, vehicleInfo: String?, licensePlate: String?, description: String?, items: [ServiceOrderItemPayload], mechanics: [ServiceOrderMechanicPayload]) async throws {
        let escaped = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let itemsPayload = items.map { ["productId": $0.productId, "quantity": $0.quantity, "unitPrice": $0.unitPrice, "subtotal": $0.subtotal] as [String: Any] }
        let mechanicsPayload = mechanics.map { ["mechanicId": $0.mechanicId, "functionDescription": $0.functionDescription, "value": $0.value] as [String: Any] }
        var payload: [String: Any] = ["customerName": customerName, "items": itemsPayload, "mechanics": mechanicsPayload]
        if let v = vehicleInfo { payload["vehicleInfo"] = v }
        if let p = licensePlate { payload["licensePlate"] = p }
        if let d = description { payload["description"] = d }
        let data = try JSONSerialization.data(withJSONObject: payload)
        _ = try await request(path: "api/service-orders/\(escaped)", method: "PUT", body: data)
    }

    func convertServiceOrderToSale(serviceOrderId: String) async throws -> String {
        let escaped = serviceOrderId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? serviceOrderId
        let response = try await request(path: "api/service-orders/\(escaped)/convert-to-sale", method: "POST", body: "{}".data(using: .utf8))
        if let json = try? JSONSerialization.jsonObject(with: response) as? [String: Any],
           let saleId = json["saleId"] as? String {
            return saleId
        }
        return ""
    }

    func postStockMovement(productId: String, type: String, quantity: Double, reason: String?) async throws {
        var payload: [String: Any] = ["productId": productId, "type": type, "quantity": quantity]
        if let r = reason { payload["reason"] = r }
        let data = try JSONSerialization.data(withJSONObject: payload)
        _ = try await request(path: "api/stock-movements", method: "POST", body: data)
    }
}

struct CategoryCreateResponse: Codable {
    let category: Category
}

struct CustomerCreateResponse: Codable {
    let success: Bool?
    let customer: Customer?
}

struct Promotion: Codable, Identifiable {
    let id: String
    let productId: String?
    let productName: String?
    let promotionalPrice: Double?
    let originalPrice: Double?
    let startDate: String?
    let endDate: String?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id, description
        case productId = "product_id"
        case productName = "product_name"
        case promotionalPrice = "promotionalPrice"
        case originalPrice = "originalPrice"
        case startDate = "start_date"
        case endDate = "end_date"
    }
}

struct ShareWhatsAppResponse: Codable {
    let success: Bool?
    let sent: Int?
    let total: Int?
    let error: String?
}

struct SupportTicketCreateResponse: Codable {
    let success: Bool?
    let ticket: SupportTicketCreated?
}

struct SupportTicketCreated: Codable {
    let id: String?
    let ticketNumber: String?
    let subject: String?
    let status: String?
}

struct SupportTicket: Codable, Identifiable {
    let id: String
    let ticketNumber: String?
    let subject: String?
    let category: String?
    let status: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, subject, category, status
        case ticketNumber = "ticketNumber"
        case createdAt = "createdAt"
    }
}

struct SupportTicketsResponse: Codable {
    let tickets: [SupportTicket]?
}

struct ReportsSalesResponse: Codable {
    let summary: ReportsSummary?
    let byDate: [ReportsByDate]?
    let byProduct: [ReportsByProduct]?
    let byCategory: [ReportsByCategory]?
    let byPayment: [ReportsByPayment]?
}

struct ReportsSummary: Codable {
    let totalRevenue: Double?
    let totalSales: Int?
    let totalItems: Int?
}

struct ReportsByDate: Codable {
    let date: String?
    let total: Double?
    let count: Int?
}

struct ReportsByProduct: Codable {
    let productId: String?
    let name: String?
    let total: Double?
    let quantity: Int?
}

struct ReportsByCategory: Codable {
    let category: String?
    let total: Double?
}

struct ReportsByPayment: Codable {
    let method: String?
    let total: Double?
}

struct DailyReportResponse: Codable {
    let date: String?
    let sales: DailySales?
    let orders: DailyOrders?
}

struct DailySales: Codable {
    let list: [DailySaleItem]?
    let count: Int?
    let total: Double?
    let byPayment: [String: Double]?
}

struct DailySaleItem: Codable {
    let id: String?
    let total: Double?
    let paymentMethod: String?
    let customerName: String?
    let createdAt: String?
}

struct DailyOrders: Codable {
    let list: [[String: String?]]?
    let count: Int?
}

struct BotStatusResponse: Codable {
    let online: Bool?
    let configured: Bool?
    let lastMessageAt: String?
}

struct BotConversationsResponse: Codable {
    let conversations: [BotConversation]?
}

struct BotMessage: Codable, Identifiable {
    let id: String
    let direction: String?
    let body: String?
    let createdAt: String?
    let attendantName: String?
    let mediaType: String?
    let mediaId: String?

    enum CodingKeys: String, CodingKey {
        case id, direction, body
        case createdAt = "created_at"
        case attendantName = "attendant_name"
        case mediaType = "media_type"
        case mediaId = "media_id"
    }
}

struct BotMessagesResponse: Codable {
    let messages: [BotMessage]?
}

struct BotOrder: Codable, Identifiable {
    let id: String
    let orderNumber: String?
    let customerPhone: String?
    let customerName: String?
    let items: String?
    let status: String?
    let statusLabel: String?
    let notes: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, items, status, notes
        case orderNumber = "order_number"
        case customerPhone = "customer_phone"
        case customerName = "customer_name"
        case statusLabel = "status_label"
        case createdAt = "created_at"
    }
}

struct BotOrdersResponse: Codable {
    let orders: [BotOrder]?
}

struct NFeGenerateResponse: Codable {
    let id: String?
    let saleId: String?
    let number: String?
    let accessKey: String?
    let status: String?
    let issuedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, number, status
        case saleId = "saleId"
        case accessKey = "accessKey"
        case issuedAt = "issuedAt"
    }
}

struct FiscalReceiptResponse: Codable {
    let html: String?
    let receipt: FiscalReceiptInfo?
}

struct FiscalReceiptInfo: Codable {
    let id: String?
    let number: String?
    let accessKey: String?
}

// MARK: - Create Sale (POST /api/sales)

struct CreateSalePayload: Encodable {
    let items: [CreateSaleItemPayload]
    let subtotal: Double
    let discount: Double
    let total: Double
    let paymentMethod: String
    let customerId: String?
    let customerName: String?
    let customerDocument: String?
    let shouldEmitNFe: Bool?
}

struct CreateSaleItemPayload: Encodable {
    let productId: String
    let quantity: Double
    let unitPrice: Double
    let subtotal: Double
}

struct CreateSaleResponse: Decodable {
    let id: String
}
