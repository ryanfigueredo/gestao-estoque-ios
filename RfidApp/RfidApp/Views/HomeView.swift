import SwiftUI

struct HomeView: View {
    @ObservedObject var auth: AuthService

    private var greetingName: String {
        guard let name = auth.currentUser?.name else { return "Usuário" }
        return name.split(separator: " ").first.map(String.init) ?? name
    }

    private var userInitials: String {
        let name = auth.currentUser?.name ?? "U"
        let parts = name.split(separator: " ")
        if parts.count >= 2, let first = parts.first?.first, let last = parts.last?.first {
            return "\(first)\(last)".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    @State private var tenantFeatures: TenantFeatures?
    private let api = ApiClient.shared

    var body: some View {
        NavigationStack {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                HStack(spacing: AppTheme.Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.primary, AppTheme.primaryDark],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                        Text(userInitials)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Olá, \(greetingName)")
                            .font(.system(size: AppTheme.FontSize.title2, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        if let email = auth.currentUser?.email {
                            Text(email)
                                .font(.system(size: AppTheme.FontSize.caption, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 10))
                            Text(roleLabel)
                                .font(.system(size: AppTheme.FontSize.footnote, weight: .semibold))
                        }
                        .foregroundStyle(AppTheme.primary)
                    }
                    Spacer()
                }
                .padding(AppTheme.Spacing.lg)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
                .shadow(color: AppTheme.shadow, radius: 12, x: 0, y: 2)
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.top, AppTheme.Spacing.md)

                // Cards
                VStack(spacing: AppTheme.Spacing.md) {
                    Text("Acesso rápido")
                        .font(.system(size: AppTheme.FontSize.callout, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        .padding(.top, AppTheme.Spacing.lg)

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

                    HStack(spacing: AppTheme.Spacing.md) {
                        NavigationLink(value: AppRoute.nfe) {
                            QuickActionCard(icon: "doc.text.fill", title: "NF-e", subtitle: "Notas fiscais")
                        }
                        .buttonStyle(.plain)
                        if tenantFeatures?.bot == true {
                            NavigationLink(value: AppRoute.atendimento) {
                                QuickActionCard(icon: "message.fill", title: "Atendimento", subtitle: "Bot WhatsApp")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)
                }

                Spacer().frame(height: AppTheme.Spacing.xl)

                // Logout
                Button {
                    auth.logout()
                } label: {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Sair da conta")
                            .font(.system(size: AppTheme.FontSize.body, weight: .medium))
                    }
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Spacing.md)
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
            }
            .padding(.bottom, AppTheme.Spacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
        .navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .dashboard: EmptyView()
            case .produtos: ProductsScreen()
            case .vendas: SalesScreen()
            case .estoque: StockScreen()
            case .estoqueLowStock: StockScreen(filterLowStockOnly: true)
            case .caixa: CashScreen()
            case .nfe: NFeScreen()
            case .atendimento: AtendimentoScreen()
            case .pedidos: PedidosScreen()
            case .clientes: CustomersScreen()
            case .fornecedores: SuppliersScreen()
            case .compras: PurchasesScreen()
            case .categorias: CategoriesScreen()
            case .promocoes: PromotionsScreen()
            case .relatorios: ReportsScreen()
            case .ordensServico: OrdensServicoScreen()
            case .suporte: SuporteScreen()
            }
        }
        .task { await loadTenantFeatures() }
        }
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

struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.Radius.sm)
                    .fill(AppTheme.primary.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.primary)
            }
            Text(title)
                .font(.system(size: AppTheme.FontSize.title3, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(subtitle)
                .font(.system(size: AppTheme.FontSize.footnote, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
        .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 2)
    }
}
