import Foundation

enum AppConfig {
    static let productionBaseURL = "https://rfid.dmtn.com.br"
    static let defaultTimeout: TimeInterval = 30

    static var baseURL: String { productionBaseURL }
}
