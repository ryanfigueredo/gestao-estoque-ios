import Foundation

struct BotConversation: Codable, Identifiable {
    var id: String { customerPhone }
    let customerPhone: String
    let customerName: String?
    let lastMessageAt: String?
    let lastMessage: String?
    let lastDirection: String?
    let messageCount: Int?
    let isPaused: Bool?

    enum CodingKeys: String, CodingKey {
        case customerPhone = "customer_phone"
        case customerName = "customer_name"
        case lastMessageAt = "last_message_at"
        case lastMessage = "last_message"
        case lastDirection = "last_direction"
        case messageCount = "message_count"
        case isPaused = "is_paused"
    }
}
