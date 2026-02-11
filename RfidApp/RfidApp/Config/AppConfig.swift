import Foundation

enum AppConfig {
    /// API em produção – dados reais do rfid.dmtn.com.br (desktop)
    static let productionBaseURL = "https://rfid.dmtn.com.br"
    static let defaultTimeout: TimeInterval = 30

    /// Sempre produção; gráficos e KPIs puxam dados do backend em prod.
    static var baseURL: String { productionBaseURL }
}
