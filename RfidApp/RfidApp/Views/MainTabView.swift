import SwiftUI

struct MainTabView: View {
    @ObservedObject var auth: AuthService
    @EnvironmentObject var branding: TenantBrandingService
    @State private var selectedTab: MainTab = .inicio
    @State private var showMenu = false
    @State private var pendingRoute: AppRoute?
    @State private var menuNavPath: [AppRoute] = []
    @State private var tenantFeatures: TenantFeatures?
    private let api = ApiClient.shared

    enum MainTab: String, CaseIterable {
        case inicio = "Início"
        case vendas = "Vendas"
        case caixa = "Caixa"
        case atendimento = "Atendimento"
        case mais = "Mais"
    }

    private var botOnly: Bool {
        guard let f = tenantFeatures else { return false }
        return f.bot == true && f.rfid != true && f.serviceOrders != true
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab Início - Dashboard
            NavigationStack {
                HomeTabContent(auth: auth, onMenuTap: { showMenu = true })
                    .navigationDestination(for: AppRoute.self) { route in
                        destinationView(for: route)
                    }
            }
            .tabItem {
                Label("Início", systemImage: "house.fill")
            }
            .tag(MainTab.inicio)

            // Tab Vendas - oculta no plano só WhatsApp
            if !botOnly {
                NavigationStack {
                    SalesScreen()
                        .navigationDestination(for: AppRoute.self) { route in
                            destinationView(for: route)
                        }
                }
                .tabItem {
                    Label("Vendas", systemImage: "cart.fill")
                }
                .tag(MainTab.vendas)

                // Tab Caixa
                NavigationStack {
                    CashScreen()
                        .navigationDestination(for: AppRoute.self) { route in
                            destinationView(for: route)
                        }
                }
                .tabItem {
                    Label("Caixa", systemImage: "dollarsign.circle.fill")
                }
                .tag(MainTab.caixa)
            }

            // Tab Atendimento - sempre visível para fácil acompanhamento
            NavigationStack {
                AtendimentoScreen()
                    .navigationDestination(for: AppRoute.self) { route in
                        destinationView(for: route)
                    }
            }
            .tabItem {
                Label("Atendimento", systemImage: "message.fill")
            }
            .tag(MainTab.atendimento)

            // Tab Mais - Configurações e Gestão
            NavigationStack(path: $menuNavPath) {
                MenuContentView(auth: auth)
                    .navigationDestination(for: AppRoute.self) { route in
                        destinationView(for: route)
                    }
            }
            .tabItem {
                Label("Mais", systemImage: "gearshape.fill")
            }
            .tag(MainTab.mais)
        }
        .tint(branding.primaryColor)
        .sheet(isPresented: $showMenu) {
            MenuView(
                auth: auth,
                isPresented: $showMenu,
                tenantFeatures: tenantFeatures,
                onSelect: { route in
                    pendingRoute = route
                    showMenu = false
                },
                onLogout: { auth.logout() }
            )
        }
        .onChange(of: pendingRoute) { _, route in
            guard let route else { return }
            switch route {
            case .dashboard: selectedTab = .inicio
            case .vendas:
                if !botOnly { selectedTab = .vendas } else { selectedTab = .inicio }
            case .caixa:
                if !botOnly { selectedTab = .caixa } else { selectedTab = .inicio }
            case .atendimento: selectedTab = .atendimento
            default:
                selectedTab = .mais
                menuNavPath.append(route)
            }
            pendingRoute = nil
        }
        .task { await loadTenantFeatures() }
    }

    @ViewBuilder
    private func destinationView(for route: AppRoute) -> some View {
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

    private func loadTenantFeatures() async {
        do {
            let res = try await api.getTenantMe()
            tenantFeatures = res.tenant?.features
            TenantBrandingService.shared.update(branding: res.tenant?.branding)
        } catch {
            tenantFeatures = nil
            TenantBrandingService.shared.reset()
        }
    }
}

struct MenuContentView: View {
    @ObservedObject var auth: AuthService
    @StateObject private var bt = RfidBluetoothManager.shared
    @AppStorage("atendimento_display_name") private var displayNamePreview = ""

    @State private var tenantInfo: TenantInfo?
    @State private var showRfidSheet = false
    @State private var botStatus: BotStatusResponse?
    private let api = ApiClient.shared
    private var baseURL: String {
        AppConfig.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private var planLabel: String {
        guard let f = tenantInfo?.features else { return "Básico" }
        let rfid = f.rfid ?? false
        let bot = f.bot ?? false
        let os = f.serviceOrders ?? false
        if bot && !rfid && !os { return "WhatsApp" }
        if rfid && bot { return "Premium" }
        if rfid || bot || os { return "Completo" }
        return "Básico"
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: AppTheme.Spacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                            .fill(AppTheme.surfaceSecondary)
                            .frame(width: 56, height: 56)
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(AppTheme.primary)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(auth.currentUser?.name ?? "Usuário")
                            .font(.system(size: AppTheme.FontSize.body, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        if let email = auth.currentUser?.email {
                            Text(email)
                                .font(.system(size: AppTheme.FontSize.caption))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Text(tenantInfo?.name ?? "Empresa")
                            .font(.system(size: AppTheme.FontSize.footnote))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    Spacer()
                }
                .padding(.vertical, AppTheme.Spacing.xs)
                .listRowBackground(AppTheme.surface)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            } header: {
                Text("Perfil e Empresa")
            }

            Section("Plano DMTN") {
                HStack {
                    Image(systemName: "star.circle.fill")
                        .foregroundStyle(AppTheme.primary)
                    Text(planLabel)
                        .font(.system(size: AppTheme.FontSize.body, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Text("Atual")
                        .font(.system(size: AppTheme.FontSize.footnote))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .listRowBackground(AppTheme.surface)
                if planLabel == "Premium" {
                    Button {
                        if let url = URL(string: "\(baseURL)/agendar") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Label("Agendar com Especialista", systemImage: "calendar.badge.clock")
                                .font(.system(size: AppTheme.FontSize.body, weight: .medium))
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.primary)
                        }
                    }
                    .listRowBackground(AppTheme.primary.opacity(0.06))
                }
                Button {
                    if let url = URL(string: "\(baseURL)/planos") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Ver planos e preços", systemImage: "arrow.up.right.square")
                        .font(.system(size: AppTheme.FontSize.body))
                }
                .listRowBackground(AppTheme.surface)
            }

            Section("Atendimento") {
                NavigationLink {
                    AtendimentoNomeScreen()
                } label: {
                    HStack {
                        Label("Nome que o cliente vê", systemImage: "person.crop.circle")
                        Spacer()
                        Text(displayNamePreview.isEmpty ? "Não definido" : displayNamePreview)
                            .font(.system(size: AppTheme.FontSize.caption))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
                .listRowBackground(AppTheme.surface)
            }

            Section("Segurança") {
                Button {
                    if let url = URL(string: "\(baseURL)/dashboard") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Gestão de usuários", systemImage: "person.3.fill")
                }
                .listRowBackground(AppTheme.surface)
                Button {
                    if let url = URL(string: "\(baseURL)/dashboard") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Permissões de acesso", systemImage: "lock.shield.fill")
                }
                .listRowBackground(AppTheme.surface)
            }

            Section("Integrações") {
                let botOnlyPlan = (tenantInfo?.features?.bot == true)
                    && (tenantInfo?.features?.rfid != true)
                    && (tenantInfo?.features?.serviceOrders != true)
                if tenantInfo?.features?.bot == true {
                    NavigationLink(value: AppRoute.atendimento) {
                        HStack {
                            Label("Bot WhatsApp", systemImage: "message.fill")
                            Spacer()
                            if let status = botStatus, status.configured == true {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill((status.online ?? false) ? AppTheme.success : AppTheme.textTertiary)
                                        .frame(width: 8, height: 8)
                                    Text((status.online ?? false) ? "Online" : "Offline")
                                        .font(.system(size: AppTheme.FontSize.caption))
                                        .foregroundStyle((status.online ?? false) ? AppTheme.success : AppTheme.textSecondary)
                                }
                            } else {
                                Text("Configurado")
                                    .font(.system(size: AppTheme.FontSize.caption))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }
                    .listRowBackground(AppTheme.surface)
                }
                if !botOnlyPlan {
                Button {
                    bt.startScanning()
                    showRfidSheet = true
                } label: {
                    HStack {
                        Label("Leitor RFID Bluetooth", systemImage: "antenna.radiowaves.left.and.right")
                        Spacer()
                        Image(systemName: bt.isConnected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 16))
                            .foregroundStyle(bt.isConnected ? AppTheme.success : AppTheme.textTertiary)
                        Text(bt.isConnected ? "Conectado" : "Conectar")
                            .font(.system(size: AppTheme.FontSize.caption))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .listRowBackground(AppTheme.surface)
                }
            }

            Section("Suporte") {
                NavigationLink(value: AppRoute.suporte) {
                    Label("Chat de ajuda", systemImage: "headphones.circle.fill")
                }
                .listRowBackground(AppTheme.surface)
                Button {
                    if let url = URL(string: "\(baseURL)/suporte") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("FAQ e documentação", systemImage: "questionmark.circle.fill")
                }
                .listRowBackground(AppTheme.surface)
            }

            Section {
                Button(role: .destructive) {
                    auth.logout()
                } label: {
                    Label("Sair da conta", systemImage: "rectangle.portrait.and.arrow.right")
                }
                .listRowBackground(AppTheme.surface)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .navigationTitle("Configurações")
        .navigationBarTitleDisplayMode(.large)
        .task {
            do {
                let res = try await api.getTenantMe()
                tenantInfo = res.tenant
                TenantBrandingService.shared.update(branding: res.tenant?.branding)
                if res.tenant?.features?.bot == true {
                    botStatus = try? await api.getBotStatus()
                } else {
                    botStatus = nil
                }
            } catch {
                tenantInfo = nil
                botStatus = nil
            }
            // Verificação periódica do status do bot (leve, a cada 60s) – para não pesar o app
            while !Task.isCancelled, tenantInfo?.features?.bot == true {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                if Task.isCancelled { break }
                botStatus = try? await api.getBotStatus()
            }
        }
        .sheet(isPresented: $showRfidSheet) {
            DeviceListSheet(bt: bt, isPresented: $showRfidSheet)
        }
    }
}
