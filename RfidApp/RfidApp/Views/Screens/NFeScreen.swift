import SwiftUI

struct NFeScreen: View {
    @State private var nfes: [NFe] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
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
                ForEach(nfes) { n in
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        HStack {
                            Text(n.number ?? "—")
                                .font(.system(size: AppTheme.FontSize.body, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Text(n.status ?? "—")
                                .font(.system(size: AppTheme.FontSize.caption, weight: .medium))
                                .foregroundStyle(n.status == "issued" ? AppTheme.success : AppTheme.textSecondary)
                        }
                        Text(n.customerName ?? "Sem nome")
                            .font(.system(size: AppTheme.FontSize.callout))
                            .foregroundStyle(AppTheme.textSecondary)
                        if let total = n.total {
                            Text(formatCurrency(total))
                                .font(.system(size: AppTheme.FontSize.callout, weight: .semibold))
                                .foregroundStyle(AppTheme.primary)
                        }
                    }
                    .padding(.vertical, AppTheme.Spacing.xs)
                }
            }
            .listStyle(.plain)
            .refreshable { await load() }
        }
        .navigationTitle("Notas Fiscais")
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            nfes = try await api.getNFe()
        } catch {
            errorMessage = error.localizedDescription
            nfes = []
        }
        isLoading = false
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: value)) ?? "R$ 0,00"
    }
}
