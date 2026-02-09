import SwiftUI

struct PedidosScreen: View {
    @State private var orders: [BotOrder] = []
    @State private var errorMessage: String?
    private let api = ApiClient.shared

    private let statusOptions = [
        ("em_preparacao", "Em preparação"),
        ("saiu_entrega", "Saiu para entrega"),
        ("entregue", "Entregue"),
        ("cancelado", "Cancelado"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            if let msg = errorMessage {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppTheme.error)
                    Text(msg)
                        .font(.system(size: AppTheme.FontSize.caption))
                        .foregroundStyle(AppTheme.error)
                }
                .padding(AppTheme.Spacing.md)
                .frame(maxWidth: .infinity)
                .background(AppTheme.error.opacity(0.1))
            }
            List {
                ForEach(orders) { o in
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        HStack {
                            Text(o.orderNumber ?? "—")
                                .font(.system(size: AppTheme.FontSize.body, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Text(formatDate(o.createdAt ?? ""))
                                .font(.system(size: AppTheme.FontSize.caption))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        if let name = o.customerName, !name.isEmpty {
                            Text(name)
                                .font(.system(size: AppTheme.FontSize.callout))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Text(formatPhone(o.customerPhone ?? ""))
                            .font(.system(size: AppTheme.FontSize.footnote))
                            .foregroundStyle(AppTheme.primary)
                        if let items = o.items, !items.isEmpty {
                            Text(items)
                                .font(.system(size: AppTheme.FontSize.caption))
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineLimit(3)
                        }
                        Menu {
                            ForEach(statusOptions, id: \.0) { value, label in
                                Button(label) {
                                    Task {
                                        try? await api.updateOrderStatus(orderId: o.id, status: value)
                                        await load()
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: AppTheme.Spacing.xs) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text(o.statusLabel ?? o.status ?? "Alterar status")
                                    .font(.system(size: AppTheme.FontSize.footnote, weight: .medium))
                            }
                            .foregroundStyle(statusColor(o.status ?? ""))
                            .padding(.horizontal, AppTheme.Spacing.sm)
                            .padding(.vertical, AppTheme.Spacing.xs)
                            .background(statusColor(o.status ?? "").opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
                        }
                    }
                    .padding(.vertical, AppTheme.Spacing.xs)
                }
            }
            .listStyle(.plain)
            .refreshable { await load() }
        }
        .navigationTitle("Pedidos WhatsApp")
        .task { await load() }
    }

    private func load() async {
        errorMessage = nil
        do {
            orders = try await api.getBotOrders()
        } catch {
            errorMessage = error.localizedDescription
            orders = []
        }
    }

    private func statusColor(_ s: String) -> Color {
        switch s {
        case "entregue": return AppTheme.success
        case "saiu_entrega": return AppTheme.primary
        case "cancelado": return AppTheme.textTertiary
        default: return AppTheme.warning
        }
    }

    private func formatPhone(_ s: String) -> String {
        let digits = s.filter { $0.isNumber }
        if digits.count == 11 { return "(\(digits.prefix(2))) \(digits.dropFirst(2).prefix(5))-\(digits.suffix(4))" }
        if digits.count == 10 { return "(\(digits.prefix(2))) \(digits.dropFirst(2).prefix(4))-\(digits.suffix(4))" }
        return s
    }

    private func formatDate(_ s: String) -> String {
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: s) ?? ISO8601DateFormatter().date(from: s.replacingOccurrences(of: "Z", with: "+00:00")) {
            let f = DateFormatter()
            f.dateStyle = .short
            f.timeStyle = .short
            f.locale = Locale(identifier: "pt_BR")
            return f.string(from: d)
        }
        return String(s.prefix(16))
    }
}
