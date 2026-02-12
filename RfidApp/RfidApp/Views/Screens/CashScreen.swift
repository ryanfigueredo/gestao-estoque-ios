import SwiftUI

struct CashScreen: View {
    @State private var report: DailyReportResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedDate = Date()
    @State private var selectedSaleForDetail: Sale?
    private let api = ApiClient.shared

    var body: some View {
        VStack(spacing: 0) {
            DatePicker("Data", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .padding(AppTheme.Spacing.md)
                .background(AppTheme.surface)
                .onChange(of: selectedDate) {
                    Task { await load() }
                }

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

            if let r = report {
                ScrollView {
                    VStack(spacing: AppTheme.Spacing.lg) {
                        VStack(spacing: AppTheme.Spacing.xs) {
                            Text("Total vendas do dia")
                                .font(.system(size: AppTheme.FontSize.callout, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                            Text(formatCurrency(r.sales?.total ?? 0))
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(AppTheme.primary)
                            Text("\(r.sales?.count ?? 0) vendas")
                                .font(.system(size: AppTheme.FontSize.caption))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(AppTheme.Spacing.lg)
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))

                        if let byPayment = r.sales?.byPayment, !byPayment.isEmpty {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                                Text("Por forma de pagamento")
                                    .font(.system(size: AppTheme.FontSize.callout, weight: .semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                ForEach(Array(byPayment.keys.sorted()), id: \.self) { key in
                                    HStack {
                                        Text(paymentLabel(key))
                                            .foregroundStyle(AppTheme.textSecondary)
                                        Spacer()
                                        Text(formatCurrency(byPayment[key] ?? 0))
                                            .fontWeight(.semibold)
                                            .foregroundStyle(AppTheme.textPrimary)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            .padding(AppTheme.Spacing.lg)
                            .background(AppTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
                        }

                        if let ord = r.orders, (ord.count ?? 0) > 0 {
                            HStack(spacing: AppTheme.Spacing.md) {
                                Image(systemName: "message.fill")
                                    .font(.title2)
                                    .foregroundStyle(AppTheme.primary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Pedidos WhatsApp")
                                        .font(.system(size: AppTheme.FontSize.body, weight: .semibold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text("\(ord.count ?? 0) pedidos no dia")
                                        .font(.system(size: AppTheme.FontSize.caption))
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                Spacer()
                            }
                            .padding(AppTheme.Spacing.lg)
                            .background(AppTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
                        }

                        // Vendas do dia – clique para ver detalhes
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            HStack(spacing: AppTheme.Spacing.sm) {
                                Image(systemName: "cart.fill")
                                    .font(.title2)
                                    .foregroundStyle(AppTheme.primary)
                                Text("Vendas do dia")
                                    .font(.system(size: AppTheme.FontSize.callout, weight: .semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                            if let list = r.sales?.list, !list.isEmpty {
                                ForEach(Array(list.enumerated()), id: \.offset) { _, item in
                                    Button {
                                        if let id = item.id, !id.isEmpty {
                                            selectedSaleForDetail = Sale.fromDailyItem(
                                                id: id,
                                                customerName: item.customerName,
                                                total: item.total,
                                                paymentMethod: item.paymentMethod,
                                                createdAt: item.createdAt
                                            )
                                        }
                                    } label: {
                                        HStack(spacing: AppTheme.Spacing.md) {
                                            Image(systemName: "receipt.fill")
                                                .font(.title3)
                                                .foregroundStyle(AppTheme.primary)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(item.customerName ?? "Cliente não informado")
                                                    .font(.system(size: AppTheme.FontSize.body, weight: .medium))
                                                    .foregroundStyle(AppTheme.textPrimary)
                                                if let pm = item.paymentMethod, !pm.isEmpty {
                                                    Text(paymentLabel(pm))
                                                        .font(.system(size: AppTheme.FontSize.caption))
                                                        .foregroundStyle(AppTheme.textSecondary)
                                                }
                                            }
                                            Spacer()
                                            Text(formatCurrency(item.total ?? 0))
                                                .font(.system(size: AppTheme.FontSize.callout, weight: .semibold))
                                                .foregroundStyle(AppTheme.primary)
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(AppTheme.textTertiary)
                                        }
                                        .padding(AppTheme.Spacing.md)
                                        .background(AppTheme.surfaceSecondary)
                                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                                    }
                                    .buttonStyle(.plain)
                                }
                            } else {
                                Text("Nenhuma venda neste dia")
                                    .font(.system(size: AppTheme.FontSize.body))
                                    .foregroundStyle(AppTheme.textTertiary)
                                    .frame(maxWidth: .infinity)
                                    .padding(AppTheme.Spacing.xl)
                            }
                        }
                        .padding(AppTheme.Spacing.lg)
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
                    }
                    .padding(AppTheme.Spacing.lg)
                }
            }
        }
        .navigationTitle("Caixa")
        .sheet(item: $selectedSaleForDetail) { sale in
            NavigationStack {
                SaleDetailScreen(sale: sale)
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func paymentLabel(_ pm: String) -> String {
        switch pm.lowercased() {
        case "cash": return "Dinheiro"
        case "credit": return "Crédito"
        case "debit": return "Débito"
        case "pix": return "PIX"
        case "fiado": return "Prazo"
        default: return pm
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: selectedDate)
        do {
            report = try await api.getDailyReport(date: dateStr)
        } catch {
            errorMessage = error.localizedDescription
            report = nil
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
