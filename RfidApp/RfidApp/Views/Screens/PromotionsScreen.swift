import SwiftUI

struct PromotionsScreen: View {
    @State private var promotions: [Promotion] = []
    @State private var products: [Product] = []
    @State private var isLoading = true
    @State private var showActiveOnly = true
    @State private var errorMessage: String?
    @State private var showFormSheet = false
    @State private var editingPromotion: Promotion?
    @State private var showShareSheet = false
    @State private var shareMessage = ""
    @State private var sharing = false
    private let api = ApiClient.shared

    private var today: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private var activePromotions: [Promotion] {
        promotions.filter { p in
            let start = p.startDate ?? ""
            let end = p.endDate ?? ""
            return start <= today && end >= today
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                if let msg = errorMessage {
                    Text(msg)
                        .font(.system(size: AppTheme.FontSize.caption))
                        .foregroundStyle(AppTheme.error)
                        .padding(AppTheme.Spacing.md)
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.error.opacity(0.1))
                }

                // Controles
                HStack(spacing: AppTheme.Spacing.md) {
                    Toggle("Só ativas", isOn: $showActiveOnly)
                        .labelsHidden()
                    Text("Só ativas")
                        .font(.system(size: AppTheme.FontSize.callout))

                    Spacer()

                    Button {
                        showShareSheet = true
                    } label: {
                        Label("Divulgar WhatsApp", systemImage: "message.fill")
                            .font(.system(size: AppTheme.FontSize.callout, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, AppTheme.Spacing.md)
                            .padding(.vertical, AppTheme.Spacing.sm)
                            .background(AppTheme.success)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                    }
                    .disabled(sharing || activePromotions.isEmpty)

                    Button {
                        editingPromotion = nil
                        showFormSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.primary)
                    }
                }
                .padding(AppTheme.Spacing.md)

                if !shareMessage.isEmpty {
                    Text(shareMessage)
                        .font(.system(size: AppTheme.FontSize.caption))
                        .foregroundStyle(shareMessage.hasPrefix("Enviado") ? AppTheme.success : AppTheme.error)
                        .padding(AppTheme.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background((shareMessage.hasPrefix("Enviado") ? AppTheme.success : AppTheme.error).opacity(0.1))
                }

                if isLoading && promotions.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Spacing.xxl)
                } else if promotions.isEmpty {
                    VStack(spacing: AppTheme.Spacing.md) {
                        Image(systemName: "tag.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(AppTheme.textTertiary)
                        Text(showActiveOnly ? "Nenhuma promoção ativa" : "Nenhuma promoção cadastrada")
                            .font(.system(size: AppTheme.FontSize.body))
                            .foregroundStyle(AppTheme.textSecondary)
                        Button("Criar primeira promoção") {
                            showFormSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Spacing.xxl)
                } else {
                    LazyVStack(spacing: AppTheme.Spacing.md) {
                        ForEach(displayedPromotions) { p in
                            PromotionCard(
                                promotion: p,
                                today: today,
                                onEdit: {
                                    editingPromotion = p
                                },
                                onDelete: {
                                    Task { await deletePromotion(p) }
                                }
                            )
                        }
                    }
                }
            }
            .padding(AppTheme.Spacing.lg)
        }
        .background(AppTheme.background)
        .navigationTitle("Promoções")
        .refreshable { await load() }
        .task { await load() }
        .sheet(isPresented: $showFormSheet) {
            PromotionFormSheet(
                promotion: editingPromotion,
                products: products,
                onDismiss: {
                    showFormSheet = false
                    editingPromotion = nil
                },
                onSuccess: {
                    showFormSheet = false
                    editingPromotion = nil
                    Task { await load() }
                }
            )
        }
        .sheet(item: $editingPromotion) { p in
            PromotionFormSheet(
                promotion: p,
                products: products,
                onDismiss: { editingPromotion = nil },
                onSuccess: {
                    editingPromotion = nil
                    Task { await load() }
                }
            )
        }
        .sheet(isPresented: $showShareSheet) {
            ShareWhatsAppSheet(
                activeCount: activePromotions.count,
                onDismiss: { showShareSheet = false },
                onShare: { mode, phones in
                    shareMessage = ""
                    sharing = true
                    showShareSheet = false
                    do {
                        let res = try await api.sharePromotionsWhatsApp(mode: mode, phones: phones)
                        if res.success == true {
                            shareMessage = "Enviado para \(res.sent ?? 0) contato(s)! Total: \(res.total ?? 0)"
                        } else {
                            shareMessage = res.error ?? "Erro ao enviar"
                        }
                    } catch {
                        shareMessage = error.localizedDescription
                    }
                    sharing = false
                }
            )
        }
    }

    private var displayedPromotions: [Promotion] {
        showActiveOnly ? activePromotions : promotions
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            promotions = try await api.getPromotions(activeOnly: false)
        } catch {
            errorMessage = error.localizedDescription
            promotions = []
        }
        do {
            products = try await api.getProducts()
        } catch {
            products = []
        }
        isLoading = false
    }

    private func deletePromotion(_ p: Promotion) async {
        do {
            try await api.deletePromotion(id: p.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct PromotionCard: View {
    let promotion: Promotion
    let today: String
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var isActive: Bool {
        let start = promotion.startDate ?? ""
        let end = promotion.endDate ?? ""
        return start <= today && end >= today
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                Text(promotion.productName ?? "Produto")
                    .font(.system(size: AppTheme.FontSize.body, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                if isActive {
                    Text("Ativa")
                        .font(.system(size: AppTheme.FontSize.footnote, weight: .semibold))
                        .foregroundStyle(AppTheme.success)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.success.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Spacer()
            }
            HStack(spacing: AppTheme.Spacing.xs) {
                if let orig = promotion.originalPrice, orig > 0 {
                    Text(formatCurrency(orig))
                        .strikethrough()
                        .font(.system(size: AppTheme.FontSize.caption))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Text("→")
                    .foregroundStyle(AppTheme.textSecondary)
                Text(formatCurrency(promotion.promotionalPrice ?? 0))
                    .font(.system(size: AppTheme.FontSize.body, weight: .bold))
                    .foregroundStyle(AppTheme.success)
            }
            if let start = promotion.startDate, let end = promotion.endDate {
                Text("\(formatDate(start)) até \(formatDate(end))")
                    .font(.system(size: AppTheme.FontSize.footnote))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            if let d = promotion.description, !d.isEmpty {
                Text(d)
                    .font(.system(size: AppTheme.FontSize.caption))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            HStack(spacing: AppTheme.Spacing.md) {
                Button("Editar", action: onEdit)
                    .font(.system(size: AppTheme.FontSize.footnote, weight: .medium))
                    .foregroundStyle(AppTheme.primary)
                Button("Excluir", action: onDelete)
                    .font(.system(size: AppTheme.FontSize.footnote, weight: .medium))
                    .foregroundStyle(AppTheme.error)
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
    }

    private func formatCurrency(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "pt_BR")
        return f.string(from: NSNumber(value: v)) ?? "R$ 0,00"
    }

    private func formatDate(_ s: String) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        if let d = fmt.date(from: s) {
            fmt.dateFormat = "dd/MM/yyyy"
            return fmt.string(from: d)
        }
        return s
    }
}

struct PromotionFormSheet: View {
    let promotion: Promotion?
    let products: [Product]
    let onDismiss: () -> Void
    let onSuccess: () -> Void

    @State private var productId: String = ""
    @State private var promotionalPriceStr: String = ""
    @State private var startDate: String = ""
    @State private var endDate: String = ""
    @State private var description: String = ""
    @State private var isLoading = false
    @State private var errorMsg: String?
    private let api = ApiClient.shared

    private var selectedProduct: Product? {
        products.first { $0.id == productId }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Produto") {
                    Picker("Produto", selection: $productId) {
                        Text("Selecione").tag("")
                        ForEach(products) { p in
                            Text("\(p.name) - \(formatCurrency(p.price ?? 0))").tag(p.id)
                        }
                    }
                    .disabled(promotion != nil)
                }
                Section("Preço promocional (R$)") {
                    TextField("0,00", text: $promotionalPriceStr)
                        .keyboardType(.decimalPad)
                }
                Section("Período") {
                    TextField("Início (YYYY-MM-DD)", text: $startDate)
                    TextField("Fim (YYYY-MM-DD)", text: $endDate)
                }
                Section("Descrição (opcional)") {
                    TextField("Ex: Oferta da semana", text: $description)
                }
                if let msg = errorMsg {
                    Section {
                        Text(msg).foregroundStyle(AppTheme.error)
                    }
                }
            }
            .navigationTitle(promotion == nil ? "Nova Promoção" : "Editar Promoção")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        Task { await submit() }
                    }
                    .disabled(isLoading || productId.isEmpty || promotionalPriceStr.isEmpty || startDate.isEmpty || endDate.isEmpty)
                }
            }
        }
        .onAppear {
            if let p = promotion {
                productId = p.productId ?? ""
                promotionalPriceStr = String(p.promotionalPrice ?? 0)
                startDate = p.startDate ?? ""
                endDate = p.endDate ?? ""
                description = p.description ?? ""
            } else {
                let fmt = DateFormatter()
                fmt.dateFormat = "yyyy-MM-dd"
                startDate = fmt.string(from: Date())
                var next = Date()
                next.addTimeInterval(7 * 24 * 60 * 60)
                endDate = fmt.string(from: next)
            }
        }
    }

    private func formatCurrency(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "pt_BR")
        return f.string(from: NSNumber(value: v)) ?? "R$ 0,00"
    }

    private func submit() async {
        guard let price = Double(promotionalPriceStr.replacingOccurrences(of: ",", with: ".")),
              !productId.isEmpty, !startDate.isEmpty, !endDate.isEmpty else {
            errorMsg = "Preencha todos os campos"
            return
        }

        isLoading = true
        errorMsg = nil
        do {
            if let p = promotion {
                try await api.updatePromotion(id: p.id, promotionalPrice: price, startDate: startDate, endDate: endDate, description: description.isEmpty ? nil : description)
            } else {
                try await api.createPromotion(productId: productId, promotionalPrice: price, startDate: startDate, endDate: endDate, description: description.isEmpty ? nil : description)
            }
            onSuccess()
        } catch {
            errorMsg = error.localizedDescription
        }
        isLoading = false
    }
}

struct ShareWhatsAppSheet: View {
    let activeCount: Int
    let onDismiss: () -> Void
    let onShare: (String, [String]?) async -> Void

    @State private var mode = "all"
    @State private var specificPhones = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Enviar para \(activeCount) promoção(ões) ativa(s)")
                        .font(.system(size: AppTheme.FontSize.callout))
                }
                Section("Enviar para") {
                    Picker("Destino", selection: $mode) {
                        Text("Todos os clientes").tag("all")
                        Text("Telefones específicos").tag("specific")
                    }
                    .pickerStyle(.segmented)
                    if mode == "specific" {
                        TextField("Números (um por linha ou vírgula)\nEx: 11999999999, 21988887777", text: $specificPhones, axis: .vertical)
                            .lineLimit(4...6)
                    }
                }
            }
            .navigationTitle("Divulgar no WhatsApp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enviar") {
                        Task {
                            isLoading = true
                            var phones: [String]? = nil
                            if mode == "specific" {
                                phones = specificPhones
                                    .components(separatedBy: CharacterSet(charactersIn: "\n,; "))
                                    .map { String($0.filter { $0.isNumber }) }
                                    .filter { $0.count >= 10 }
                            }
                            await onShare(mode, phones)
                            isLoading = false
                        }
                    }
                    .disabled(isLoading || (mode == "specific" && specificPhones.trimmingCharacters(in: .whitespaces).isEmpty))
                }
            }
        }
    }
}
