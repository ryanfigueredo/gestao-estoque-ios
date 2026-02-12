import SwiftUI

struct SaleDetailScreen: View {
    @Environment(\.dismiss) private var dismiss
    let sale: Sale

    @State private var detail: SaleDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isGeneratingNfe = false
    @State private var isLoadingCupom = false
    @State private var fiscalReceiptItemToShow: FiscalReceiptItem?

    private let api = ApiClient.shared

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: AppTheme.Spacing.lg) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(AppTheme.primary)
                    Text("Carregando...")
                        .font(.system(size: AppTheme.FontSize.callout))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = errorMessage {
                VStack(spacing: AppTheme.Spacing.md) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(AppTheme.error)
                    Text(err)
                        .font(.system(size: AppTheme.FontSize.body))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Tentar novamente") {
                        Task { await load() }
                    }
                    .font(.system(size: AppTheme.FontSize.body, weight: .semibold))
                    .foregroundStyle(AppTheme.primary)
                }
                .padding(AppTheme.Spacing.xl)
            } else if let d = detail {
                ScrollView {
                    VStack(spacing: AppTheme.Spacing.lg) {
                        // Badges (NF-e, Prazo)
                        badgesSection(d)
                        // Card cabeçalho
                        headerCard(d)
                        // Ações (Emitir NF-e, Cupom fiscal)
                        actionsSection(d)
                        // Itens
                        itemsSection(d)
                        // Resumo
                        summaryCard(d)
                    }
                    .padding(.bottom, AppTheme.Spacing.xl)
                }
            }
        }
        .fullScreenCover(item: $fiscalReceiptItemToShow) { item in
            FiscalReceiptSheet(htmlContent: item.html, saleId: sale.id)
        }
        .background(AppTheme.background)
        .navigationTitle("Detalhes da venda")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Fechar") { dismiss() }
            }
        }
        .task { await load() }
    }

    private func badgesSection(_ d: SaleDetail) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            if let nfe = d.nfeNumber, !nfe.isEmpty {
                HStack(spacing: AppTheme.Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                    Text("NF-e emitida: \(nfe)")
                        .font(.system(size: AppTheme.FontSize.footnote, weight: .medium))
                }
                .foregroundStyle(AppTheme.success)
                .padding(.horizontal, AppTheme.Spacing.sm)
                .padding(.vertical, AppTheme.Spacing.xs)
                .background(AppTheme.success.opacity(0.15))
                .clipShape(Capsule())
            } else if d.shouldEmitNfe == true {
                HStack(spacing: AppTheme.Spacing.xs) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 14))
                    Text("NF-e pendente")
                        .font(.system(size: AppTheme.FontSize.footnote, weight: .medium))
                }
                .foregroundStyle(AppTheme.warning)
                .padding(.horizontal, AppTheme.Spacing.sm)
                .padding(.vertical, AppTheme.Spacing.xs)
                .background(AppTheme.warning.opacity(0.15))
                .clipShape(Capsule())
            }

            if isFiado(d) {
                HStack(spacing: AppTheme.Spacing.xs) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 14))
                    Text("Venda no fiado")
                        .font(.system(size: AppTheme.FontSize.footnote, weight: .medium))
                }
                .foregroundStyle(AppTheme.primary)
                .padding(.horizontal, AppTheme.Spacing.sm)
                .padding(.vertical, AppTheme.Spacing.xs)
                .background(AppTheme.primary.opacity(0.15))
                .clipShape(Capsule())
            }
            Spacer()
        }
        .padding(.horizontal)
    }

    private func actionsSection(_ d: SaleDetail) -> some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            // Só mostra "Emitir NF-e" quando o cliente escolheu emitir na venda (should_emit_nfe)
            if (d.shouldEmitNfe == true) && (d.nfeNumber?.isEmpty ?? true) {
                Button {
                    Task { await emitNfe() }
                } label: {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        if isGeneratingNfe {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "doc.badge.plus")
                        }
                        Text("Emitir NF-e")
                            .font(.system(size: AppTheme.FontSize.body, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Spacing.md)
                    .background(AppTheme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                }
                .disabled(isGeneratingNfe)
            }

            Button {
                Task { await loadCupomFiscal() }
            } label: {
                HStack(spacing: AppTheme.Spacing.sm) {
                    if isLoadingCupom {
                        ProgressView()
                            .tint(AppTheme.primary)
                    } else {
                        Image(systemName: "printer.fill")
                    }
                    Text("Cupom fiscal / PDF")
                        .font(.system(size: AppTheme.FontSize.body, weight: .semibold))
                }
                .foregroundStyle(AppTheme.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.md)
                .background(AppTheme.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
            }
            .disabled(isLoadingCupom)
        }
        .padding(.horizontal)
    }

    private func headerCard(_ d: SaleDetail) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.primary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(d.customerName ?? "Cliente não informado")
                        .font(.system(size: AppTheme.FontSize.title3, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    if let doc = d.customerDocument, !doc.isEmpty {
                        Text(doc)
                            .font(.system(size: AppTheme.FontSize.caption))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                }
                Spacer()
            }

            HStack(spacing: AppTheme.Spacing.lg) {
                if let pm = d.paymentMethod, !pm.isEmpty {
                    Label(paymentMethodLabel(pm), systemImage: isFiado(d) ? "hand.raised.fill" : "creditcard.fill")
                        .font(.system(size: AppTheme.FontSize.footnote, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                if let date = d.createdAt {
                    Label(formatDate(date), systemImage: "calendar")
                        .font(.system(size: AppTheme.FontSize.footnote))
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }

            if let status = d.status, !status.isEmpty {
                HStack(spacing: AppTheme.Spacing.xs) {
                    Circle()
                        .fill(statusColor(status))
                        .frame(width: 8, height: 8)
                    Text(statusLabel(status))
                        .font(.system(size: AppTheme.FontSize.footnote, weight: .medium))
                        .foregroundStyle(statusColor(status))
                }
            }
        }
        .padding(AppTheme.Spacing.lg)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
        .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 2)
        .padding(.horizontal)
    }

    private func itemsSection(_ d: SaleDetail) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Itens da venda")
                .font(.system(size: AppTheme.FontSize.callout, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal)

            if let items = d.items, !items.isEmpty {
                ForEach(items, id: \.id) { item in
                    HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                        Text("\(Int(item.quantity ?? 0))x")
                            .font(.system(size: AppTheme.FontSize.body, weight: .semibold))
                            .foregroundStyle(AppTheme.primary)
                            .frame(width: 36, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.product?.name ?? "Produto")
                                .font(.system(size: AppTheme.FontSize.body, weight: .medium))
                                .foregroundStyle(AppTheme.textPrimary)
                            if let sku = item.product?.sku, !sku.isEmpty {
                                Text("SKU: \(sku)")
                                    .font(.system(size: AppTheme.FontSize.caption))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                            Text("\(formatCurrency(item.unitPrice ?? 0)) un.")
                                .font(.system(size: AppTheme.FontSize.caption))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        Text(formatCurrency(item.subtotal ?? 0))
                            .font(.system(size: AppTheme.FontSize.body, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                    .padding(.horizontal)
                }
            } else {
                Text("Nenhum item registrado")
                    .font(.system(size: AppTheme.FontSize.body))
                    .foregroundStyle(AppTheme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(AppTheme.Spacing.xl)
            }
        }
    }

    private func summaryCard(_ d: SaleDetail) -> some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            if let sub = d.subtotal, sub > 0 {
                summaryRow("Subtotal", formatCurrency(sub))
            }
            if let disc = d.discount, disc > 0 {
                summaryRow("Desconto", "-\(formatCurrency(disc))")
                    .foregroundStyle(AppTheme.error)
            }
            if let nfe = d.nfeNumber, !nfe.isEmpty {
                HStack {
                    Text("NF-e")
                        .font(.system(size: AppTheme.FontSize.body))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Text(nfe)
                        .font(.system(size: AppTheme.FontSize.body, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }
            Divider()
                .padding(.vertical, AppTheme.Spacing.xs)
            HStack {
                Text("Total")
                    .font(.system(size: AppTheme.FontSize.title3, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text(formatCurrency(d.total ?? 0))
                    .font(.system(size: AppTheme.FontSize.title2, weight: .bold))
                    .foregroundStyle(AppTheme.primary)
            }
        }
        .padding(AppTheme.Spacing.lg)
        .background(AppTheme.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg)
                .stroke(AppTheme.primary.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: AppTheme.FontSize.body))
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: AppTheme.FontSize.body, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "completed", "concluído": return AppTheme.success
        case "pending", "pendente": return AppTheme.warning
        case "cancelled", "cancelado": return AppTheme.error
        default: return AppTheme.textSecondary
        }
    }

    private func statusLabel(_ status: String) -> String {
        switch status.lowercased() {
        case "completed": return "Concluída"
        case "pending": return "Pendente"
        case "cancelled": return "Cancelada"
        default: return status
        }
    }

    private func isFiado(_ d: SaleDetail) -> Bool {
        (d.paymentMethod?.lowercased() ?? "") == "fiado"
    }

    private func paymentMethodLabel(_ pm: String) -> String {
        switch pm.lowercased() {
        case "cash": return "Dinheiro"
        case "credit": return "Crédito"
        case "debit": return "Débito"
        case "pix": return "PIX"
        case "fiado": return "Prazo"
        default: return pm
        }
    }

    private func emitNfe() async {
        isGeneratingNfe = true
        do {
            _ = try await api.postNfeGenerate(saleId: sale.id)
            await MainActor.run {
                isGeneratingNfe = false
                Task { await load() }
            }
        } catch {
            await MainActor.run {
                isGeneratingNfe = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadCupomFiscal() async {
        isLoadingCupom = true
        do {
            let res = try await api.postFiscalReceiptPdf(saleId: sale.id)
            await MainActor.run {
                isLoadingCupom = false
                if let html = res.html, !html.isEmpty {
                    fiscalReceiptItemToShow = FiscalReceiptItem(html: html)
                } else {
                    errorMessage = "Não foi possível gerar o cupom fiscal"
                }
            }
        } catch {
            await MainActor.run {
                isLoadingCupom = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            detail = try await api.getSale(id: sale.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: value)) ?? "R$ 0,00"
    }

    private func formatDate(_ s: String) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: s) ?? ISO8601DateFormatter().date(from: s.replacingOccurrences(of: "Z", with: "+00:00")) {
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .short
            f.locale = Locale(identifier: "pt_BR")
            return f.string(from: d)
        }
        return String(s.prefix(16))
    }
}

private struct FiscalReceiptItem: Identifiable {
    let id = UUID()
    let html: String
}
