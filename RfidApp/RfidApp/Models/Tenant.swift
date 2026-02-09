import Foundation

struct TenantInfo: Codable {
    let id: String
    let name: String?
    let slug: String?
    let status: String?
    let features: TenantFeatures?
    let branding: TenantBranding?
}

struct TenantBranding: Codable {
    let primaryColor: String?
    let logoUrl: String?
}

struct TenantFeatures: Codable {
    let rfid: Bool?
    let bot: Bool?
    let serviceOrders: Bool?
}

struct TenantMeResponse: Codable {
    let tenant: TenantInfo?
}
