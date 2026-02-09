import SwiftUI

struct OrdensServicoScreen: View {
    @StateObject private var viewModel = OSViewModel()
    @State private var showNovaOSSheet = false
    @State private var selectedOrdemForDetail: OrdemServico?

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.ordens.isEmpty {
                VStack(spacing: AppTheme.Spacing.lg) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(AppTheme.primary)
                    Text("Carregando ordens...")
                        .font(.system(size: AppTheme.FontSize.callout))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.ordens) { ordem in
                        Button {
                            selectedOrdemForDetail = ordem
                        } label: {
                            OrdemServicoRow(ordem: ordem)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
                .refreshable { await viewModel.loadOrdens() }
            }
        }
        .background(AppTheme.background)
        .navigationTitle("Ordens de Serviço")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNovaOSSheet = true
                } label: {
                    Label("Nova OS", systemImage: "plus.circle.fill")
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if viewModel.ordens.isEmpty && !viewModel.isLoading {
                EmptyStateView {
                    showNovaOSSheet = true
                }
            } else {
                // Botão flutuante sempre visível para criar nova OS
                Button {
                    showNovaOSSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(AppTheme.primary)
                        .clipShape(Circle())
                        .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 4)
                }
                .padding(AppTheme.Spacing.lg)
            }
        }
        .sheet(isPresented: $showNovaOSSheet) {
            NovaOrdemServicoSheet(viewModel: viewModel) {
                showNovaOSSheet = false
                if let created = viewModel.selectedOrdem {
                    selectedOrdemForDetail = created
                }
            }
        }
        .sheet(item: $selectedOrdemForDetail) { ordem in
            NavigationStack {
                OrdemServicoDetailScreen(ordemId: ordem.id, viewModel: viewModel)
            }
        }
        .task { await viewModel.loadOrdens() }
    }
}

// MARK: - OrdemServicoRow

private struct OrdemServicoRow: View {
    let ordem: OrdemServico

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: ordem.status.iconName)
                .font(.title2)
                .foregroundStyle(statusColor(ordem.status))
            VStack(alignment: .leading, spacing: 4) {
                Text(ordem.number ?? ordem.id)
                    .font(.system(size: AppTheme.FontSize.body, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(ordem.customerName)
                    .font(.system(size: AppTheme.FontSize.caption))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCurrency(ordem.total ?? ordem.calculatedTotal))
                    .font(.system(size: AppTheme.FontSize.callout, weight: .bold))
                    .foregroundStyle(AppTheme.primary)
                Text(ordem.status.label)
                    .font(.system(size: AppTheme.FontSize.caption, weight: .medium))
                    .foregroundStyle(statusColor(ordem.status))
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textTertiary)
        }
        .padding(.vertical, AppTheme.Spacing.sm)
    }

    private func statusColor(_ status: OSStatus) -> Color {
        switch status {
        case .aberta: return AppTheme.primary
        case .emAndamento: return AppTheme.warning
        case .aguardandoPecas: return AppTheme.warning
        case .finalizada: return AppTheme.success
        case .cancelada: return AppTheme.error
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "pt_BR")
        return f.string(from: NSNumber(value: value)) ?? "R$ 0,00"
    }
}

// MARK: - EmptyStateView

private struct EmptyStateView: View {
    let onCreateTap: () -> Void

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.textTertiary)
            Text("Nenhuma ordem de serviço")
                .font(.system(size: AppTheme.FontSize.title3, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("Toque em + para criar uma nova ordem")
                .font(.system(size: AppTheme.FontSize.caption))
                .foregroundStyle(AppTheme.textSecondary)
            Button("Nova Ordem de Serviço", action: onCreateTap)
                .font(.system(size: AppTheme.FontSize.body, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.vertical, AppTheme.Spacing.md)
                .background(AppTheme.primary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
