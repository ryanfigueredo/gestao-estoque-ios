import SwiftUI
import Charts

struct HomeTabContent: View {
    @ObservedObject var auth: AuthService
    @StateObject private var bt = RfidBluetoothManager.shared
    let onMenuTap: () -> Void

    @State private var tenantFeatures: TenantFeatures?
    @State private var dailyReport: DailyReportResponse?
    @State private var salesChartData: [ReportsByDate] = []
    @State private var products: [Product] = []
    @State private var serviceOrders: [ServiceOrder] = []
    @State private var isLoading = true
    @State private var loadError: String?
    private let api = ApiClient.shared

    private var greetingName: String {
        guard let name = auth.currentUser?.name else { return "Usuário" }
        return name.split(separator: " ").first.map(String.init) ?? name
    }

    private var salesCount: Int { dailyReport?.sales?.count ?? 0 }
    private var revenueToday: Double { dailyReport?.sales?.total ?? 0 }
    private var totalProducts: Int { products.count }
    private var lowStockCount: Int {
        products.filter { ($0.stock ?? 0) <= ($0.minStock ?? 0) && ($0.minStock ?? 0) > 0 }.count
    }
    private var pendingOSCount: Int {
        serviceOrders.filter { ($0.status ?? "").lowercased() == "open" }.count
    }
    private var showOS: Bool { tenantFeatures?.serviceOrders == true }

    private var botOnly: Bool {
        guard let f = tenantFeatures else { return false }
        return f.bot == true && f.rfid != true && f.serviceOrders != true
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header compacto: Olá + status BLE + menu
                HStack(spacing: AppTheme.Spacing.sm) {
                    Text("Olá, \(greetingName)")
                        .font(.system(size: AppTheme.FontSize.callout, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Image(systemName: bt.isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                        .font(.system(size: 14))
                        .foregroundStyle(bt.isConnected ? AppTheme.success : AppTheme.textTertiary)
                        .accessibilityLabel(bt.isConnected ? "Leitor RFID conectado" : "Leitor RFID desconectado")
                    Button(action: onMenuTap) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(width: 40, height: 40)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.top, AppTheme.Spacing.sm)

                if let err = loadError {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppTheme.error)
                        Text(err)
                            .font(.system(size: AppTheme.FontSize.caption))
                            .foregroundStyle(AppTheme.error)
                    }
                    .padding(AppTheme.Spacing.sm)
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.error.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .padding(.top, AppTheme.Spacing.sm)
                }

                // Gráfico – visão do negócio (oculto no plano só WhatsApp)
                if !botOnly {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppTheme.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Vendas últimos 7 dias")
                                .font(.system(size: AppTheme.FontSize.title3, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            if !salesChartData.isEmpty {
                                let weekTotal = salesChartData.reduce(0) { $0 + ($1.total ?? 0) }
                                Text("Total da semana: \(formatCurrency(weekTotal))")
                                    .font(.system(size: AppTheme.FontSize.caption, weight: .medium))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .padding(.top, AppTheme.Spacing.lg)
                    .padding(.bottom, AppTheme.Spacing.sm)

                    if salesChartData.isEmpty {
                        HStack(spacing: AppTheme.Spacing.sm) {
                            Image(systemName: "chart.bar.xaxis")
                                .font(.system(size: 28))
                                .foregroundStyle(AppTheme.textTertiary)
                            Text("Sem dados de vendas no período")
                                .font(.system(size: AppTheme.FontSize.callout))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                    } else {
                        SalesChartView(data: salesChartData)
                            .frame(height: 200)
                            .padding(.horizontal, AppTheme.Spacing.sm)
                    }
                }
                .padding(.bottom, AppTheme.Spacing.lg)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.lg)
                        .stroke(AppTheme.border.opacity(0.6), lineWidth: 1)
                )
                .shadow(color: AppTheme.shadow, radius: 10, x: 0, y: 4)
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.top, AppTheme.Spacing.md)
                }

                // KPIs – prioridade para números (oculto no plano só WhatsApp)
                if !botOnly {
                VStack(spacing: AppTheme.Spacing.sm) {
                    Text("Hoje")
                        .font(.system(size: AppTheme.FontSize.callout, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        .padding(.top, AppTheme.Spacing.md)

                    HStack(spacing: AppTheme.Spacing.md) {
                        NavigationLink(value: AppRoute.vendas) {
                            KPICard(
                                icon: "cart.fill",
                                title: "Vendas hoje",
                                value: "\(salesCount)",
                                loading: isLoading
                            )
                        }
                        .buttonStyle(.plain)
                        NavigationLink(value: AppRoute.caixa) {
                            KPICard(
                                icon: "dollarsign.circle.fill",
                                title: "Receita",
                                value: formatCurrency(revenueToday),
                                loading: isLoading
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)

                    HStack(spacing: AppTheme.Spacing.md) {
                        NavigationLink(value: AppRoute.estoqueLowStock) {
                            KPICard(
                                icon: "exclamationmark.triangle.fill",
                                title: "Estoque baixo",
                                value: "\(lowStockCount)",
                                loading: isLoading,
                                accent: lowStockCount > 0
                            )
                        }
                        .buttonStyle(.plain)
                        if showOS {
                            NavigationLink(value: AppRoute.ordensServico) {
                                KPICard(
                                    icon: "wrench.and.screwdriver.fill",
                                    title: "Pendências OS",
                                    value: "\(pendingOSCount)",
                                    loading: isLoading,
                                    accent: pendingOSCount > 0
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink(value: AppRoute.produtos) {
                                KPICard(
                                    icon: "shippingbox.fill",
                                    title: "Produtos",
                                    value: "\(totalProducts)",
                                    loading: isLoading
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)
                }
                }

                // Cards
                VStack(spacing: AppTheme.Spacing.md) {
                    Text(botOnly ? "Atendimento" : "Acesso rápido")
                        .font(.system(size: AppTheme.FontSize.callout, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        .padding(.top, AppTheme.Spacing.lg)

                    if botOnly {
                        HStack(spacing: AppTheme.Spacing.md) {
                            NavigationLink(value: AppRoute.atendimento) {
                                QuickActionCard(icon: "message.fill", title: "Atendimento WhatsApp", subtitle: "Conversas e atendimento")
                            }
                            .buttonStyle(.plain)
                            NavigationLink(value: AppRoute.pedidos) {
                                QuickActionCard(icon: "clipboard.fill", title: "Pedidos WhatsApp", subtitle: "Pedidos recebidos")
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, AppTheme.Spacing.lg)
                    } else {
                    HStack(spacing: AppTheme.Spacing.md) {
                        NavigationLink(value: AppRoute.produtos) {
                            QuickActionCard(icon: "barcode.viewfinder", title: "Produtos", subtitle: "Buscar e localizar por RFID")
                        }
                        .buttonStyle(.plain)
                        NavigationLink(value: AppRoute.vendas) {
                            QuickActionCard(icon: "cart.fill", title: "Vendas", subtitle: "Histórico")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)

                    HStack(spacing: AppTheme.Spacing.md) {
                        NavigationLink(value: AppRoute.estoque) {
                            QuickActionCard(icon: "shippingbox.fill", title: "Estoque", subtitle: "Movimentações e inventário")
                        }
                        .buttonStyle(.plain)
                        NavigationLink(value: AppRoute.caixa) {
                            QuickActionCard(icon: "dollarsign.circle.fill", title: "Caixa", subtitle: "Fechamento")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)

                    if tenantFeatures?.bot == true {
                        HStack(spacing: AppTheme.Spacing.md) {
                            NavigationLink(value: AppRoute.atendimento) {
                                QuickActionCard(icon: "message.fill", title: "Atendimento", subtitle: "Bot WhatsApp")
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, AppTheme.Spacing.lg)
                    }
                    if tenantFeatures?.serviceOrders == true {
                        HStack(spacing: AppTheme.Spacing.md) {
                            NavigationLink(value: AppRoute.ordensServico) {
                                QuickActionCard(icon: "wrench.and.screwdriver.fill", title: "Ordem de Serviço", subtitle: "Oficina e peças")
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, AppTheme.Spacing.lg)
                    }
                    }
                }

                Spacer().frame(height: AppTheme.Spacing.xxl)
            }
            .padding(.bottom, AppTheme.Spacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
        .navigationTitle("Início")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await loadTenantFeatures()
            await loadDashboardData()
        }
        .task {
            await loadTenantFeatures()
            await loadDashboardData()
        }
    }

    private func loadDashboardData() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        do {
            dailyReport = try await api.getDailyReport(date: today)
        } catch {
            dailyReport = nil
            if loadError == nil { loadError = error.localizedDescription }
        }
        let cal = Calendar.current
        if let start = cal.date(byAdding: .day, value: -6, to: Date()) {
            let startStr = formatter.string(from: start)
            do {
                let res = try await api.getReportsSales(startDate: startStr, endDate: today)
                salesChartData = res.byDate ?? []
            } catch {
                salesChartData = []
                if loadError == nil { loadError = error.localizedDescription }
            }
        }
        do {
            products = try await api.getProducts()
        } catch {
            products = []
            if loadError == nil { loadError = error.localizedDescription }
        }
        if tenantFeatures?.serviceOrders == true {
            do {
                serviceOrders = try await api.getServiceOrders()
            } catch {
                serviceOrders = []
            }
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: value)) ?? "R$ 0,00"
    }

    private func loadTenantFeatures() async {
        do {
            let res = try await api.getTenantMe()
            tenantFeatures = res.tenant?.features
            TenantBrandingService.shared.update(branding: res.tenant?.branding)
        } catch {
            tenantFeatures = nil
        }
    }

    private var roleLabel: String {
        switch auth.currentUser?.role ?? "" {
        case "master": return "Master"
        case "admin": return "Administrador"
        case "operator": return "Operador"
        case "comercial": return "Comercial"
        case "atendente": return "Atendente"
        default: return auth.currentUser?.role ?? "-"
        }
    }
}

struct SalesChartView: View {
    let data: [ReportsByDate]
    private static let shortFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM"
        f.locale = Locale(identifier: "pt_BR")
        return f
    }()
    private struct ChartDay: Identifiable {
        let id: String
        let label: String
        let total: Double
    }

    private var chartItems: [ChartDay] {
        data.compactMap { item in
            guard let d = item.date, let date = parseDate(d) else { return nil }
            return ChartDay(
                id: d,
                label: Self.shortFmt.string(from: date),
                total: item.total ?? 0
            )
        }
    }

    private var maxTotal: Double {
        chartItems.map(\.total).max() ?? 1
    }

    private func parseDate(_ s: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s)
    }

    private func formatShort(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        }
        return String(format: "%.0f", value)
    }

    var body: some View {
        Chart(chartItems) { item in
            BarMark(
                x: .value("Dia", item.label),
                y: .value("Receita", item.total)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primary.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(6)
            .annotation(position: .top, spacing: 4) {
                if item.total > 0 {
                    Text(formatShort(item.total))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(AppTheme.border.opacity(0.8))
                AxisValueLabel {
                    if let v = value.as(Double.self), v >= 0 {
                        Text(formatShort(v))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisValueLabel {
                    if let label = value.as(String.self) {
                        Text(label)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
        }
        .chartYScale(domain: 0 ... (maxTotal * 1.15 + 1))
    }
}

struct KPICard: View {
    let icon: String
    let title: String
    let value: String
    var loading: Bool = false
    var accent: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.Radius.sm)
                    .fill((accent ? AppTheme.error : AppTheme.primary).opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accent ? AppTheme.error : AppTheme.primary)
            }
            Text(title)
                .font(.system(size: AppTheme.FontSize.footnote, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
            if loading {
                Text("...")
                    .font(.system(size: AppTheme.FontSize.title3, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
            } else {
                Text(value)
                    .font(.system(size: AppTheme.FontSize.title3, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
        .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 2)
    }
}
