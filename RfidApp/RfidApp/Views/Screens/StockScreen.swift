import SwiftUI

struct StockScreen: View {
    var filterLowStockOnly: Bool = false
    @State private var products: [Product] = []
    @State private var movements: [StockMovement] = []
    @State private var searchTerm = ""
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showMovementSheet = false
    @State private var movementProduct: Product?
    @State private var movementType = "entry"
    private let api = ApiClient.shared

    private var filteredProducts: [Product] {
        var list = products
        if filterLowStockOnly {
            list = list.filter { ($0.stock ?? 0) <= ($0.minStock ?? 0) && ($0.minStock ?? 0) > 0 }
        }
        guard !searchTerm.isEmpty else { return list }
        let term = searchTerm.lowercased()
        return list.filter {
            $0.name.lowercased().contains(term) ||
            ($0.sku?.lowercased().contains(term) ?? false) ||
            ($0.rfidTag?.lowercased().contains(term) ?? false)
        }
    }

    private var lowStockProducts: [Product] {
        products.filter { ($0.stock ?? 0) <= ($0.minStock ?? 0) && ($0.minStock ?? 0) > 0 }
    }

    private var recentMovements: [StockMovement] {
        Array(movements.prefix(20))
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

                // Botões Entrada / Saída
                HStack(spacing: AppTheme.Spacing.md) {
                    Button {
                        movementProduct = nil
                        movementType = "entry"
                        showMovementSheet = true
                    } label: {
                        Label("Entrada", systemImage: "arrow.down.circle.fill")
                            .font(.system(size: AppTheme.FontSize.callout, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppTheme.Spacing.md)
                            .background(AppTheme.success.opacity(0.15))
                            .foregroundStyle(AppTheme.success)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                    }
                    .buttonStyle(.plain)

                    Button {
                        movementProduct = nil
                        movementType = "exit"
                        showMovementSheet = true
                    } label: {
                        Label("Saída", systemImage: "arrow.up.circle.fill")
                            .font(.system(size: AppTheme.FontSize.callout, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppTheme.Spacing.md)
                            .background(AppTheme.error.opacity(0.15))
                            .foregroundStyle(AppTheme.error)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                    }
                    .buttonStyle(.plain)
                }

                // Alerta estoque baixo
                if !lowStockProducts.isEmpty {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        HStack(spacing: AppTheme.Spacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(AppTheme.error)
                            Text("\(lowStockProducts.count) produto(s) com estoque abaixo do mínimo")
                                .font(.system(size: AppTheme.FontSize.callout, weight: .semibold))
                                .foregroundStyle(AppTheme.error)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.error.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                }

                // Busca
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(AppTheme.textTertiary)
                    TextField("Buscar produtos...", text: $searchTerm)
                        .textFieldStyle(.plain)
                }
                .padding(AppTheme.Spacing.md)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))

                // Produtos em estoque
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("Produtos em Estoque")
                        .font(.system(size: AppTheme.FontSize.callout, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    if isLoading && products.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppTheme.Spacing.xl)
                    } else if filteredProducts.isEmpty {
                        Text("Nenhum produto encontrado")
                            .font(.system(size: AppTheme.FontSize.body))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppTheme.Spacing.xl)
                    } else {
                        ForEach(filteredProducts) { p in
                            StockProductRow(product: p) {
                                movementProduct = p
                                movementType = "entry"
                                showMovementSheet = true
                            }
                        }
                    }
                }
                .padding(AppTheme.Spacing.md)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))

                // Movimentações recentes
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("Movimentações Recentes")
                        .font(.system(size: AppTheme.FontSize.callout, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    if recentMovements.isEmpty && !isLoading {
                        Text("Nenhuma movimentação")
                            .font(.system(size: AppTheme.FontSize.body))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppTheme.Spacing.md)
                    } else {
                        ForEach(recentMovements) { m in
                            HStack(spacing: AppTheme.Spacing.md) {
                                Image(systemName: typeIcon(m.type ?? ""))
                                    .font(.title3)
                                    .foregroundStyle(typeColor(m.type ?? ""))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(m.product?.name ?? "Produto")
                                        .font(.system(size: AppTheme.FontSize.body, weight: .medium))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text("\(m.type ?? "—") • \(formatDate(m.createdAt ?? ""))")
                                        .font(.system(size: AppTheme.FontSize.footnote))
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                Spacer()
                                Text((m.quantity ?? 0) >= 0 ? "+\(Int(m.quantity ?? 0))" : "\(Int(m.quantity ?? 0))")
                                    .font(.system(size: AppTheme.FontSize.callout, weight: .bold))
                                    .foregroundStyle(typeColor(m.type ?? ""))
                            }
                            .padding(.vertical, AppTheme.Spacing.xs)
                        }
                    }
                }
                .padding(AppTheme.Spacing.md)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
            }
            .padding(AppTheme.Spacing.lg)
        }
        .background(AppTheme.background)
        .navigationTitle(filterLowStockOnly ? "Estoque Baixo" : "Estoque")
        .refreshable { await load() }
        .task { await load() }
        .sheet(isPresented: $showMovementSheet) {
            StockMovementSheet(
                product: movementProduct,
                type: movementType,
                products: products,
                onDismiss: { showMovementSheet = false },
                onSuccess: {
                    showMovementSheet = false
                    Task { await load() }
                }
            )
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            products = try await api.getProducts()
        } catch {
            products = []
        }
        do {
            movements = try await api.getStockMovements()
        } catch {
            movements = []
        }
        isLoading = false
    }

    private func typeIcon(_ t: String) -> String {
        switch t.lowercased() {
        case "entrada": return "arrow.down.circle.fill"
        case "saída", "saida": return "arrow.up.circle.fill"
        case "ajuste": return "slider.horizontal.3"
        default: return "shippingbox.fill"
        }
    }

    private func typeColor(_ t: String) -> Color {
        switch t.lowercased() {
        case "entrada": return AppTheme.success
        case "saída", "saida": return AppTheme.error
        case "ajuste": return AppTheme.warning
        default: return AppTheme.textSecondary
        }
    }

    private func formatDate(_ s: String) -> String {
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: s) ?? ISO8601DateFormatter().date(from: s.replacingOccurrences(of: "Z", with: "+00:00")) {
            let f = DateFormatter()
            f.dateStyle = .short
            f.timeStyle = .short
            f.locale = Locale(identifier: "pt_BR")
            return f.string(from: d)
        }
        return String(s.prefix(16))
    }
}

struct StockProductRow: View {
    let product: Product
    let onEntryTap: () -> Void

    private var isLowStock: Bool {
        let s = product.stock ?? 0
        let m = product.minStock ?? 0
        return m > 0 && s <= m
    }

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(.system(size: AppTheme.FontSize.body, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(product.sku ?? "")
                    .font(.system(size: AppTheme.FontSize.footnote))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(product.stock ?? 0))")
                    .font(.system(size: AppTheme.FontSize.body, weight: .bold))
                    .foregroundStyle(isLowStock ? AppTheme.error : AppTheme.textPrimary)
                if isLowStock {
                    Text("Baixo")
                        .font(.system(size: AppTheme.FontSize.footnote))
                        .foregroundStyle(AppTheme.error)
                }
            }
            Button(action: onEntryTap) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.primary)
            }
        }
        .padding(.vertical, AppTheme.Spacing.sm)
    }
}

struct StockMovementSheet: View {
    let product: Product?
    let type: String
    let products: [Product]
    let onDismiss: () -> Void
    let onSuccess: () -> Void

    @State private var selectedProductId: String = ""
    @State private var quantityStr: String = ""
    @State private var reason: String = ""
    @State private var isLoading = false
    @State private var errorMsg: String?
    private let api = ApiClient.shared

    private var selectedProduct: Product? {
        products.first { $0.id == selectedProductId }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let p = product {
                    Section("Produto") {
                        Text(p.name)
                        Text("Estoque atual: \(Int(p.stock ?? 0))")
                            .font(.system(size: AppTheme.FontSize.caption))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                } else {
                    Section("Produto") {
                        Picker("Produto", selection: $selectedProductId) {
                            Text("Selecione").tag("")
                            ForEach(products) { p in
                                Text("\(p.name) (\(Int(p.stock ?? 0)))").tag(p.id)
                            }
                        }
                    }
                }

                Section("Quantidade") {
                    TextField(type == "exit" ? "Qtd a sair" : "Qtd a adicionar", text: $quantityStr)
                        .keyboardType(.decimalPad)
                }

                Section("Motivo (opcional)") {
                    TextField("Ex: Entrada de fornecedor", text: $reason)
                }

                if let msg = errorMsg {
                    Section {
                        Text(msg)
                            .foregroundStyle(AppTheme.error)
                    }
                }
            }
            .navigationTitle(type == "entry" ? "Entrada" : "Saída")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        Task { await submit() }
                    }
                    .disabled(isLoading || quantityStr.isEmpty || (product == nil && selectedProductId.isEmpty))
                }
            }
        }
        .onAppear {
            if let p = product {
                selectedProductId = p.id
            } else if let first = products.first {
                selectedProductId = first.id
            }
        }
    }

    private func submit() async {
        let productId = product?.id ?? selectedProductId
        guard !productId.isEmpty,
              let qty = Double(quantityStr.replacingOccurrences(of: ",", with: ".")) else {
            errorMsg = "Informe a quantidade"
            return
        }
        guard qty > 0 else {
            errorMsg = "Quantidade deve ser maior que zero"
            return
        }

        isLoading = true
        errorMsg = nil
        do {
            let r = reason.isEmpty ? nil : reason
            try await api.postStockMovement(productId: productId, type: type, quantity: qty, reason: r)
            onSuccess()
        } catch {
            errorMsg = error.localizedDescription
        }
        isLoading = false
    }
}
