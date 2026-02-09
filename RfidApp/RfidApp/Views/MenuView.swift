import SwiftUI

struct MenuView: View {
    @ObservedObject var auth: AuthService
    @Binding var isPresented: Bool
    let tenantFeatures: TenantFeatures?
    let onSelect: (AppRoute) -> Void
    let onLogout: () -> Void

    private var menuItems: [(route: AppRoute, label: String, icon: String)] {
        var items: [(AppRoute, String, String)] = []
        let role = auth.currentUser?.role ?? ""
        let isMaster = role == "master"
        let hasBot = isMaster || (tenantFeatures?.bot == true)
        let showOS = tenantFeatures?.serviceOrders == true
        let botOnly = hasBot && tenantFeatures?.rfid != true && tenantFeatures?.serviceOrders != true

        switch role {
        case "atendente":
            items = [
                (.atendimento, "Atendimento WhatsApp", "message.fill"),
                (.pedidos, "Pedidos WhatsApp", "clipboard.fill"),
            ]
        case "operator":
            if botOnly {
                items = [
                    (.dashboard, "Início", "house.fill"),
                    (.atendimento, "Atendimento WhatsApp", "message.fill"),
                    (.pedidos, "Pedidos WhatsApp", "clipboard.fill"),
                ]
            } else {
                items = [
                    (.dashboard, "Início", "house.fill"),
                    (.vendas, "Vendas", "cart.fill"),
                    (.caixa, "Caixa", "dollarsign.circle.fill"),
                    (.clientes, "Clientes", "person.2.fill"),
                    (.produtos, "Produtos", "barcode.viewfinder"),
                ]
                if hasBot {
                    items.append((.atendimento, "Atendimento WhatsApp", "message.fill"))
                    items.append((.pedidos, "Pedidos WhatsApp", "clipboard.fill"))
                }
            }
        case "comercial", "admin", "master":
            if botOnly && !isMaster {
                items = [
                    (.dashboard, "Início", "house.fill"),
                    (.atendimento, "Atendimento WhatsApp", "message.fill"),
                    (.pedidos, "Pedidos WhatsApp", "clipboard.fill"),
                    (.suporte, "Suporte", "headphones.circle.fill"),
                ]
            } else {
                items = [
                    (.dashboard, "Início", "house.fill"),
                    (.produtos, "Produtos", "barcode.viewfinder"),
                    (.vendas, "Vendas", "cart.fill"),
                    (.caixa, "Caixa", "dollarsign.circle.fill"),
                    (.clientes, "Clientes", "person.2.fill"),
                    (.fornecedores, "Fornecedores", "building.2.fill"),
                    (.compras, "Compras", "cart.badge.plus"),
                    (.estoque, "Estoque", "shippingbox.fill"),
                    (.categorias, "Categorias", "folder.fill"),
                    (.promocoes, "Promoções", "tag.fill"),
                    (.relatorios, "Relatórios", "chart.bar.fill"),
                    (.nfe, "Notas Fiscais", "doc.text.fill"),
                    (.atendimento, "Atendimento WhatsApp", "message.fill"),
                    (.pedidos, "Pedidos WhatsApp", "clipboard.fill"),
                ]
                if !hasBot {
                    items.removeAll { $0.0 == .atendimento || $0.0 == .pedidos }
                }
            }
        default:
            items = [
                (.dashboard, "Início", "house.fill"),
                (.produtos, "Produtos", "barcode.viewfinder"),
                (.vendas, "Vendas", "cart.fill"),
                (.caixa, "Caixa", "dollarsign.circle.fill"),
                (.clientes, "Clientes", "person.2.fill"),
                (.estoque, "Estoque", "shippingbox.fill"),
                (.nfe, "Notas Fiscais", "doc.text.fill"),
            ]
            if hasBot {
                items.append((.atendimento, "Atendimento WhatsApp", "message.fill"))
                items.append((.pedidos, "Pedidos WhatsApp", "clipboard.fill"))
            }
        }
        if showOS, let idx = items.firstIndex(where: { $0.0 == .categorias }) {
            items.insert((.ordensServico, "Ordem de Serviço", "wrench.and.screwdriver.fill"), at: idx)
        } else if showOS {
            items.append((.ordensServico, "Ordem de Serviço", "wrench.and.screwdriver.fill"))
        }
        return items
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: "line.3.horizontal.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(AppTheme.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Menu")
                        .font(.system(size: AppTheme.FontSize.title2, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(auth.currentUser?.email ?? "")
                        .font(.system(size: AppTheme.FontSize.caption))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
            .padding(AppTheme.Spacing.lg)
            .background(AppTheme.surface)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(menuItems, id: \.route) { item in
                        Button {
                            onSelect(item.route)
                            isPresented = false
                        } label: {
                            HStack(spacing: AppTheme.Spacing.md) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 18))
                                    .foregroundStyle(AppTheme.primary)
                                    .frame(width: 28, alignment: .center)
                                Text(item.label)
                                    .font(.system(size: AppTheme.FontSize.body, weight: .medium))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                            .padding(AppTheme.Spacing.md)
                            .background(AppTheme.surface)
                        }
                        .buttonStyle(.plain)
                    }

                    Divider()
                        .padding(.vertical, AppTheme.Spacing.sm)

                    // Suporte DMTN
                    Button {
                        onSelect(.suporte)
                        isPresented = false
                    } label: {
                        HStack(spacing: AppTheme.Spacing.md) {
                            Image(systemName: "headphones.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(AppTheme.primary)
                                .frame(width: 28, alignment: .center)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Suporte DMTN")
                                    .font(.system(size: AppTheme.FontSize.body, weight: .semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text("Tempo de resposta, contato e atendimento")
                                    .font(.system(size: AppTheme.FontSize.caption))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        .padding(AppTheme.Spacing.md)
                        .background(AppTheme.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                    }
                    .buttonStyle(.plain)

                    Spacer().frame(height: AppTheme.Spacing.xl)

                    // Logout
                    Button {
                        onLogout()
                        isPresented = false
                    } label: {
                        HStack(spacing: AppTheme.Spacing.md) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 18))
                                .foregroundStyle(AppTheme.error)
                            Text("Sair da conta")
                                .font(.system(size: AppTheme.FontSize.body, weight: .medium))
                                .foregroundStyle(AppTheme.error)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(AppTheme.Spacing.md)
                    }
                    .buttonStyle(.plain)
                }
                .padding(AppTheme.Spacing.md)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
    }
}
