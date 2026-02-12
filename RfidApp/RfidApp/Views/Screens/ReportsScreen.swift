import SwiftUI

struct ReportsScreen: View {
    @State private var data: ReportsSalesResponse?
    @State private var categories: [Category] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var selectedCategoryId: String = ""
    private let api = ApiClient.shared

    private let paymentLabels: [String: String] = [
        "pix": "PIX",
        "cash": "Dinheiro",
        "debit": "Débito",
        "credit": "Crédito",
        "fiado": "Prazo",
        "outros": "Outros"
    ]

    private var selectedCategoryName: String? {
        guard !selectedCategoryId.isEmpty else { return nil }
        return categories.first { $0.id == selectedCategoryId }?.name
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
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

                // Filtros
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    Text("Período")
                        .font(.system(size: AppTheme.FontSize.callout, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    // Atalhos rápidos
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppTheme.Spacing.sm) {
                            PeriodButton(title: "7 dias") { applyPeriod(days: 7) }
                            PeriodButton(title: "30 dias") { applyPeriod(days: 30) }
                            PeriodButton(title: "90 dias") { applyPeriod(days: 90) }
                        }
                    }

                    HStack(spacing: AppTheme.Spacing.md) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("De")
                                .font(.system(size: AppTheme.FontSize.footnote))
                                .foregroundStyle(AppTheme.textSecondary)
                            DatePicker("", selection: $startDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Até")
                                .font(.system(size: AppTheme.FontSize.footnote))
                                .foregroundStyle(AppTheme.textSecondary)
                            DatePicker("", selection: $endDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Categoria")
                            .font(.system(size: AppTheme.FontSize.footnote))
                            .foregroundStyle(AppTheme.textSecondary)
                        Picker("Categoria", selection: $selectedCategoryId) {
                            Text("Todas").tag("")
                            ForEach(categories) { c in
                                Text(c.name ?? "").tag(c.id)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    Button {
                        Task { await load() }
                    } label: {
                        Label("Atualizar", systemImage: "arrow.clockwise")
                            .font(.system(size: AppTheme.FontSize.callout, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppTheme.Spacing.sm)
                            .background(AppTheme.primary)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                    }
                    .buttonStyle(.plain)
                }
                .padding(AppTheme.Spacing.md)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))

                if isLoading && data == nil {
                    ProgressView("Carregando...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Spacing.xxl)
                } else if let d = data {
                    // Resumo - 3 cards em grid
                    VStack(spacing: AppTheme.Spacing.md) {
                        Text("Resumo do período")
                            .font(.system(size: AppTheme.FontSize.callout, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: AppTheme.Spacing.md) {
                            ReportSummaryCard(
                                title: "Receita",
                                value: formatCurrency(d.summary?.totalRevenue ?? 0),
                                icon: "chart.line.uptrend.xyaxis",
                                color: AppTheme.primary
                            )
                            ReportSummaryCard(
                                title: "Vendas",
                                value: "\(d.summary?.totalSales ?? 0)",
                                icon: "cart.fill",
                                color: AppTheme.success
                            )
                        }
                        ReportSummaryCard(
                            title: "Itens vendidos",
                            value: "\(d.summary?.totalItems ?? 0)",
                            icon: "shippingbox.fill",
                            color: AppTheme.warning
                        )
                    }
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))

                    // Vendas por data (lista)
                    if let byDate = d.byDate, !byDate.isEmpty {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            Text("Vendas por dia")
                                .font(.system(size: AppTheme.FontSize.callout, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            ForEach(Array(byDate.suffix(10).reversed().enumerated()), id: \.element.date) { _, item in
                                HStack {
                                    Text(formatDateShort(item.date ?? ""))
                                        .font(.system(size: AppTheme.FontSize.body))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Spacer()
                                    Text(formatCurrency(item.total ?? 0))
                                        .font(.system(size: AppTheme.FontSize.callout, weight: .semibold))
                                        .foregroundStyle(AppTheme.primary)
                                    Text("(\(item.count ?? 0) vendas)")
                                        .font(.system(size: AppTheme.FontSize.footnote))
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(AppTheme.Spacing.md)
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
                    }

                    // Top Produtos
                    if let byProduct = d.byProduct, !byProduct.isEmpty {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            Text("Top Produtos")
                                .font(.system(size: AppTheme.FontSize.callout, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            ForEach(Array(byProduct.prefix(10).enumerated()), id: \.element.productId) { i, p in
                                HStack {
                                    Text("\(i + 1).")
                                        .font(.system(size: AppTheme.FontSize.footnote, weight: .medium))
                                        .foregroundStyle(AppTheme.textSecondary)
                                        .frame(width: 20, alignment: .leading)
                                    Text(p.name ?? "Produto")
                                        .font(.system(size: AppTheme.FontSize.body))
                                        .foregroundStyle(AppTheme.textPrimary)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(formatCurrency(p.total ?? 0))
                                        .font(.system(size: AppTheme.FontSize.callout, weight: .semibold))
                                        .foregroundStyle(AppTheme.primary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(AppTheme.Spacing.md)
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
                    }

                    // Por forma de pagamento
                    if let byPayment = d.byPayment, !byPayment.isEmpty {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            Text("Por forma de pagamento")
                                .font(.system(size: AppTheme.FontSize.callout, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            ForEach(Array(byPayment.enumerated()), id: \.offset) { _, p in
                                HStack {
                                    Text(paymentLabels[p.method ?? ""] ?? p.method ?? "—")
                                        .font(.system(size: AppTheme.FontSize.body))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Spacer()
                                    Text(formatCurrency(p.total ?? 0))
                                        .font(.system(size: AppTheme.FontSize.callout, weight: .medium))
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(AppTheme.Spacing.md)
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
                    }
                }
            }
            .padding(AppTheme.Spacing.lg)
        }
        .background(AppTheme.background)
        .navigationTitle("Relatórios")
        .task {
            await loadCategories()
            await load()
        }
        .onChange(of: startDate) { _, _ in Task { await load() } }
        .onChange(of: endDate) { _, _ in Task { await load() } }
        .onChange(of: selectedCategoryId) { _, _ in Task { await load() } }
    }

    private func applyPeriod(days: Int) {
        endDate = Date()
        startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let startStr = fmt.string(from: startDate)
        let endStr = fmt.string(from: endDate)
        let cat = selectedCategoryName
        do {
            data = try await api.getReportsSales(
                startDate: startStr,
                endDate: endStr,
                category: cat
            )
        } catch {
            errorMessage = error.localizedDescription
            data = nil
        }
        isLoading = false
    }

    private func loadCategories() async {
        do {
            categories = try await api.getCategories()
        } catch {
            categories = []
        }
    }

    private func formatCurrency(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "pt_BR")
        return f.string(from: NSNumber(value: v)) ?? "R$ 0,00"
    }

    private func formatDateShort(_ s: String) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        if let d = fmt.date(from: s) {
            fmt.dateFormat = "dd/MM"
            return fmt.string(from: d)
        }
        return s
    }
}

struct PeriodButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: AppTheme.FontSize.footnote, weight: .semibold))
                .foregroundStyle(AppTheme.primary)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(AppTheme.primary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
        }
        .buttonStyle(.plain)
    }
}

struct ReportSummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: AppTheme.FontSize.footnote))
                    .foregroundStyle(AppTheme.textSecondary)
                Text(value)
                    .font(.system(size: AppTheme.FontSize.title3, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer()
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
    }
}
