import SwiftUI
import Combine

final class TenantBrandingService: ObservableObject {
    static let shared = TenantBrandingService()
    
    @Published private(set) var primaryColor: Color = AppTheme.primary
    @Published private(set) var primaryLight: Color = AppTheme.primaryLight
    @Published private(set) var primaryDark: Color = AppTheme.primaryDark
    @Published private(set) var logoUrl: String?
    
    private init() {}
    
    func update(branding: TenantBranding?) {
        guard let hex = branding?.primaryColor, let c = Color(hex: hex) else {
            primaryColor = AppTheme.primary
            primaryLight = AppTheme.primaryLight
            primaryDark = AppTheme.primaryDark
            logoUrl = nil
            return
        }
        primaryColor = c
        primaryLight = c.opacity(0.85)
        primaryDark = c.opacity(0.7)
        logoUrl = branding?.logoUrl
    }
    
    func reset() {
        primaryColor = AppTheme.primary
        primaryLight = AppTheme.primaryLight
        primaryDark = AppTheme.primaryDark
        logoUrl = nil
    }
}

extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt64(s, radix: 16) else { return nil }
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8) & 0xFF) / 255
        let b = Double(v & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
