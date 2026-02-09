import Foundation

// MARK: - OSStatus

enum OSStatus: String, Codable, CaseIterable {
    case aberta = "open"
    case emAndamento = "in_progress"
    case aguardandoPecas = "waiting_parts"
    case finalizada = "completed"
    case cancelada = "cancelled"

    var label: String {
        switch self {
        case .aberta: return "Aberta"
        case .emAndamento: return "Em andamento"
        case .aguardandoPecas: return "Aguardando peças"
        case .finalizada: return "Finalizada"
        case .cancelada: return "Cancelada"
        }
    }

    var iconName: String {
        switch self {
        case .aberta: return "folder.badge.plus"
        case .emAndamento: return "wrench.and.screwdriver"
        case .aguardandoPecas: return "shippingbox"
        case .finalizada: return "checkmark.circle.fill"
        case .cancelada: return "xmark.circle.fill"
        }
    }

    init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "open": self = .aberta
        case "in_progress": self = .emAndamento
        case "waiting_parts": self = .aguardandoPecas
        case "completed": self = .finalizada
        case "cancelled": self = .cancelada
        default: self = .aberta
        }
    }
}

// MARK: - ItemServico

struct ItemServico: Identifiable, Equatable, Hashable {
    let id: String
    let productId: String
    let productName: String
    var quantity: Double
    let unitPrice: Double
    var subtotal: Double { quantity * unitPrice }
    var readViaRfid: Bool

    init(id: String, productId: String, productName: String, quantity: Double, unitPrice: Double, readViaRfid: Bool = false) {
        self.id = id
        self.productId = productId
        self.productName = productName
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.readViaRfid = readViaRfid
    }

    mutating func incrementQuantity(by value: Double = 1) {
        quantity += value
    }
}

// MARK: - OrdemServico

struct MecanicoOS: Identifiable, Hashable {
    let id: String
    let mechanicId: String
    let mechanicName: String
    let functionDescription: String
    let value: Double
}

struct OrdemServico: Identifiable, Hashable {
    let id: String
    let number: String?
    var customerName: String
    var vehicleInfo: String?
    var licensePlate: String?
    var description: String?
    var status: OSStatus
    let createdAt: String?
    var items: [ItemServico]
    var mechanics: [MecanicoOS]
    var subtotal: Double?
    var discount: Double?
    var total: Double?

    init(id: String, number: String?, customerName: String, vehicleInfo: String?, licensePlate: String?,
         description: String?, status: OSStatus, createdAt: String?, items: [ItemServico],
         mechanics: [MecanicoOS], subtotal: Double?, discount: Double?, total: Double?) {
        self.id = id
        self.number = number
        self.customerName = customerName
        self.vehicleInfo = vehicleInfo
        self.licensePlate = licensePlate
        self.description = description
        self.status = status
        self.createdAt = createdAt
        self.items = items
        self.mechanics = mechanics
        self.subtotal = subtotal
        self.discount = discount
        self.total = total
    }

    var calculatedTotal: Double {
        let sub = items.reduce(0) { $0 + $1.subtotal }
        let disc = discount ?? 0
        return sub - disc
    }

    var itemsReadViaRfid: Int { items.filter { $0.readViaRfid }.count }

    var allItemsRfidVerified: Bool {
        guard !items.isEmpty else { return true }
        return items.allSatisfy { $0.readViaRfid }
    }
}
