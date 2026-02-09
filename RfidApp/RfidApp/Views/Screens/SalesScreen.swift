import SwiftUI

struct SalesScreen: View {
    @State private var sales: [Sale] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedSaleForDetail: Sale?
    @State private var showNewSale = false
    private let api = ApiClient.shared

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
                ForEach(sales) { s in
                    Button {
                        selectedSaleForDetail = s
                    } label: {
                        HStack(spacing: AppTheme.Spacing.md) {
                            Image(systemName: "cart.fill")
                                .font(.title2)
                                .foregroundStyle(AppTheme.primary)
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                                Text(s.customerName ?? "Sem nome")
                                    .font(.system(size: AppTheme.FontSize.body, weight: .semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                HStack(spacing: AppTheme.Spacing.sm) {
                                    if let pm = s.paymentMethod {
                                        Text(paymentLabel(pm))
                                            .font(.system(size: AppTheme.FontSize.footnote))
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }
                                    if let date = s.createdAt {
                                        Text(formatDate(date))
                                            .font(.system(size: AppTheme.FontSize.footnote))
                                            .foregroundStyle(AppTheme.textTertiary)
                                    }
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(formatCurrency(s.total ?? 0))
                                    .font(.system(size: AppTheme.FontSize.callout, weight: .bold))
                                    .foregroundStyle(AppTheme.primary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                        }
                        .padding(.vertical, AppTheme.Spacing.sm)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .refreshable { await load() }
        }
        .navigationTitle("Vendas")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNewSale = true
                } label: {
                    Label("Nova venda", systemImage: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showNewSale, onDismiss: { Task { await load() } }) {
            NewSaleScreen(onSaleCreated: { showNewSale = false })
        }
        .sheet(item: $selectedSaleForDetail) { sale in
            NavigationStack {
                SaleDetailScreen(sale: sale)
            }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            sales = try await api.getSales()
        } catch {
            errorMessage = error.localizedDescription
            sales = []
        }
        isLoading = false
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: value)) ?? "R$ 0,00"
    }

    private func paymentLabel(_ pm: String) -> String {
        switch pm.lowercased() {
        case "cash": return "Dinheiro"
        case "credit": return "Crédito"
        case "debit": return "Débito"
        case "pix": return "PIX"
        case "fiado": return "Fiado"
        default: return pm
        }
    }

    private func formatDate(_ s: String) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
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
