import SwiftUI

struct OrdemServicoDetailScreen: View {
    let ordemId: String
    @ObservedObject var viewModel: OSViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var ordem: OrdemServico?
    @State private var showProductPicker = false
    @State private var showConvertAlert = false
    @State private var alertMessage = ""
    @State private var alertSuccess = false

    private var canAddItems: Bool {
        guard let o = ordem else { return false }
        return o.status == .aberta || o.status == .emAndamento
    }

    private var canConvert: Bool {
        ordem?.status == .aberta || ordem?.status == .emAndamento
    }

    var body: some View {
        Group {
            if ordem == nil && viewModel.isLoading {
                VStack(spacing: AppTheme.Spacing.lg) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(AppTheme.primary)
                    Text("Carregando ordem...")
                        .font(.system(size: AppTheme.FontSize.callout))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let o = ordem {
                detailContent(ordem: o)
            } else {
                ContentUnavailableView(
                    "Ordem não encontrada",
                    systemImage: "exclamationmark.triangle",
                    description: Text("A ordem pode ter sido removida.")
                )
            }
        }
        .background(AppTheme.background)
        .navigationTitle((ordem?.number ?? ordem?.id) ?? "Ordem")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Fechar") { dismiss() }
            }
            if canAddItems {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showProductPicker = true
                    } label: {
                        Label("Escanear Tag RFID", systemImage: "antenna.radiowaves.left.and.right")
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if canConvert, let o = ordem {
                floatingActions(ordem: o)
            }
        }
        .onChange(of: viewModel.selectedOrdem) { _, newValue in
            if newValue?.id == ordemId {
                ordem = newValue
            }
        }
        .sheet(isPresented: $showProductPicker) {
            ProductPickerSheet { product in
                Task {
                    await viewModel.simularEscanearRfid(ordemId: ordemId, product: product)
                    ordem = viewModel.selectedOrdem
                }
            }
        }
        .alert("Ordem de Serviço", isPresented: $showConvertAlert) {
            Button("OK", role: .cancel) {
                if alertSuccess { dismiss() }
            }
        } message: {
            Text(alertMessage)
        }
        .task {
            ordem = await viewModel.loadOrdemDetail(id: ordemId)
        }
        .refreshable {
            ordem = await viewModel.loadOrdemDetail(id: ordemId)
        }
    }

    private func detailContent(ordem: OrdemServico) -> some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                // Section: Dados do Cliente
                Section {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        DetailRow(label: "Cliente", value: ordem.customerName)
                        if let v = ordem.vehicleInfo, !v.isEmpty {
                            DetailRow(label: "Veículo/Equipamento", value: v)
                        }
                        if let p = ordem.licensePlate, !p.isEmpty {
                            DetailRow(label: "Placa", value: p)
                        }
                        if let d = ordem.description, !d.isEmpty {
                            DetailRow(label: "Observação", value: d)
                        }
                        DetailRow(label: "Status", value: ordem.status.label)
                        if let created = ordem.createdAt {
                            DetailRow(label: "Data abertura", value: formatDate(created))
                        }
                    }
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                } header: {
                    sectionHeader("Dados do Cliente")
                }

                // Section: Mecânicos
                if !ordem.mechanics.isEmpty {
                    Section {
                        VStack(spacing: 0) {
                            ForEach(ordem.mechanics) { m in
                                MecanicoRow(mecanico: m)
                                if m.id != ordem.mechanics.last?.id {
                                    Divider()
                                        .padding(.leading, 52)
                                }
                            }
                        }
                        .padding(AppTheme.Spacing.md)
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                    } header: {
                        sectionHeader("Mecânicos")
                    }
                }

                // Section: Itens
                Section {
                    if ordem.items.isEmpty {
                        VStack(spacing: AppTheme.Spacing.sm) {
                            Image(systemName: "shippingbox")
                                .font(.title)
                                .foregroundStyle(AppTheme.textTertiary)
                            Text("Nenhum item adicionado")
                                .font(.system(size: AppTheme.FontSize.callout))
                                .foregroundStyle(AppTheme.textSecondary)
                            if canAddItems {
                                Button("Escanear Tag RFID") {
                                    showProductPicker = true
                                }
                                .font(.system(size: AppTheme.FontSize.body, weight: .medium))
                                .foregroundStyle(AppTheme.primary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(AppTheme.Spacing.xl)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(ordem.items) { item in
                                ItemServicoRow(item: item)
                                if item.id != ordem.items.last?.id {
                                    Divider()
                                        .padding(.leading, 52)
                                }
                            }
                        }
                        .padding(AppTheme.Spacing.md)
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                    }
                } header: {
                    sectionHeader("Itens")
                }

                // Section: Totais
                Section {
                    VStack(spacing: AppTheme.Spacing.sm) {
                        let sub = ordem.items.reduce(0) { $0 + $1.subtotal }
                        let disc = ordem.discount ?? 0
                        let total = ordem.total ?? ordem.calculatedTotal
                        TotalRow(label: "Subtotal", value: sub)
                        if disc > 0 {
                            TotalRow(label: "Desconto", value: -disc)
                        }
                        Divider()
                        TotalRow(label: "Total", value: total, bold: true)
                        if !ordem.items.isEmpty {
                            HStack(spacing: AppTheme.Spacing.xs) {
                                Image(systemName: ordem.allItemsRfidVerified ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .foregroundStyle(ordem.allItemsRfidVerified ? AppTheme.success : AppTheme.warning)
                                Text(ordem.allItemsRfidVerified
                                     ? "Todos os itens foram verificados via RFID"
                                     : "\(ordem.items.count - ordem.itemsReadViaRfid) item(ns) pendente(s) de leitura RFID")
                                    .font(.system(size: AppTheme.FontSize.caption))
                                    .foregroundStyle(ordem.allItemsRfidVerified ? AppTheme.success : AppTheme.warning)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)
                        }
                    }
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                } header: {
                    sectionHeader("Totais")
                }

                Spacer().frame(height: 100)
            }
            .padding(AppTheme.Spacing.lg)
        }
    }

    private func floatingActions(ordem: OrdemServico) -> some View {
        VStack(spacing: 0) {
            Button {
                convertToSale(ordemId: ordem.id)
            } label: {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "cart.badge.plus")
                    Text("Converter em Venda")
                        .font(.system(size: AppTheme.FontSize.body, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(AppTheme.Spacing.md)
                .background(canConvert ? AppTheme.primary : AppTheme.textTertiary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
            }
            .disabled(!canConvert)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.bottom, AppTheme.Spacing.lg)
        }
        .background(
            LinearGradient(
                colors: [AppTheme.background.opacity(0), AppTheme.background],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: AppTheme.FontSize.callout, weight: .semibold))
            .foregroundStyle(AppTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func convertToSale(ordemId: String) {
        Task {
            let (ok, msg) = await viewModel.converterEmVenda(ordemId: ordemId)
            alertSuccess = ok
            alertMessage = msg
            showConvertAlert = true
            if ok {
                ordem = await viewModel.loadOrdemDetail(id: ordemId)
            }
        }
    }

    private func formatDate(_ value: String) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: value) ?? ISO8601DateFormatter().date(from: value) {
            let f = DateFormatter()
            f.dateStyle = .short
            f.timeStyle = .short
            f.locale = Locale(identifier: "pt_BR")
            return f.string(from: d)
        }
        return value
    }
}

// MARK: - DetailRow

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: AppTheme.FontSize.caption))
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.system(size: AppTheme.FontSize.body))
                .foregroundStyle(AppTheme.textPrimary)
        }
    }
}

// MARK: - ItemServicoRow

private struct ItemServicoRow: View {
    let item: ItemServico

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
            Image(systemName: item.readViaRfid ? "antenna.radiowaves.left.and.right" : "shippingbox")
                .font(.body)
                .foregroundStyle(item.readViaRfid ? AppTheme.success : AppTheme.textTertiary)
                .frame(width: 24, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.productName)
                    .font(.system(size: AppTheme.FontSize.body, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("\(formatQuantity(item.quantity)) × \(formatCurrency(item.unitPrice))")
                    .font(.system(size: AppTheme.FontSize.caption))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Text(formatCurrency(item.subtotal))
                .font(.system(size: AppTheme.FontSize.callout, weight: .semibold))
                .foregroundStyle(AppTheme.primary)
        }
        .padding(.vertical, AppTheme.Spacing.sm)
    }

    private func formatQuantity(_ q: Double) -> String {
        q == floor(q) ? "\(Int(q))" : String(format: "%.2f", q)
    }

    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "pt_BR")
        return f.string(from: NSNumber(value: value)) ?? "R$ 0,00"
    }
}

// MARK: - MecanicoRow

private struct MecanicoRow: View {
    let mecanico: MecanicoOS

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
            Image(systemName: "person.wrench.fill")
                .font(.body)
                .foregroundStyle(AppTheme.primary)
                .frame(width: 24, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(mecanico.mechanicName)
                    .font(.system(size: AppTheme.FontSize.body, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                if !mecanico.functionDescription.isEmpty {
                    Text(mecanico.functionDescription)
                        .font(.system(size: AppTheme.FontSize.caption))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            Spacer()
            Text(formatCurrency(mecanico.value))
                .font(.system(size: AppTheme.FontSize.callout, weight: .semibold))
                .foregroundStyle(AppTheme.primary)
        }
        .padding(.vertical, AppTheme.Spacing.sm)
    }

    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "pt_BR")
        return f.string(from: NSNumber(value: value)) ?? "R$ 0,00"
    }
}

// MARK: - TotalRow

private struct TotalRow: View {
    let label: String
    let value: Double
    var bold: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: AppTheme.FontSize.body, weight: bold ? .semibold : .regular))
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            Text(formatCurrency(value))
                .font(.system(size: AppTheme.FontSize.body, weight: bold ? .bold : .medium))
                .foregroundStyle(bold ? AppTheme.primary : AppTheme.textPrimary)
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "pt_BR")
        return f.string(from: NSNumber(value: value)) ?? "R$ 0,00"
    }
}
