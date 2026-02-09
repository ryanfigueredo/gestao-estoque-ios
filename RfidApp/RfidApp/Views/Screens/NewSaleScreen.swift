import SwiftUI

struct NewSaleScreen: View {
    @Environment(\.dismiss) private var dismiss
    var onSaleCreated: (() -> Void)?

    @State private var cartItems: [CartItem] = []
    @State private var customers: [Customer] = []
    @State private var selectedCustomerId: String?
    @State private var paymentMethod: String = "pix"
    @State private var discount: String = ""
    @State private var showProductPicker = false
    @State private var showQuickCustomerSheet = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var successSaleId: String?

    private let api = ApiClient.shared

    private var subtotal: Double {
        cartItems.reduce(0) { $0 + $1.subtotal }
    }

    private var discountValue: Double {
        Double(discount.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var total: Double {
        max(0, subtotal - discountValue)
    }

    private let paymentOptions: [(id: String, label: String)] = [
        ("pix", "PIX"),
        ("cash", "Dinheiro"),
        ("debit", "Débito"),
        ("credit", "Crédito"),
        ("fiado", "Fiado"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
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
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
                    }

                    // Produtos
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        HStack {
                            Text("Produtos")
                                .font(.system(size: AppTheme.FontSize.title3, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Button {
                                showProductPicker = true
                            } label: {
                                Label("Adicionar", systemImage: "plus.circle.fill")
                                    .font(.system(size: AppTheme.FontSize.callout, weight: .medium))
                                    .foregroundStyle(AppTheme.primary)
                            }
                        }

                        if cartItems.isEmpty {
                            Text("Nenhum produto no carrinho")
                                .font(.system(size: AppTheme.FontSize.callout))
                                .foregroundStyle(AppTheme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(AppTheme.Spacing.xl)
                                .background(AppTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                        } else {
                            ForEach(cartItems) { item in
                                CartItemRow(
                                    item: item,
                                    onQuantityChange: { newQty in
                                        updateQuantity(for: item.productId, quantity: newQty)
                                    },
                                    onRemove: {
                                        removeItem(productId: item.productId)
                                    }
                                )
                            }
                        }
                    }
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))

                    // Cliente
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        HStack {
                            Text("Cliente (opcional)")
                                .font(.system(size: AppTheme.FontSize.title3, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Button {
                                showQuickCustomerSheet = true
                            } label: {
                                Label("Cadastrar", systemImage: "person.badge.plus")
                                    .font(.system(size: AppTheme.FontSize.footnote, weight: .medium))
                                    .foregroundStyle(AppTheme.primary)
                            }
                        }
                        Picker("Cliente", selection: $selectedCustomerId) {
                            Text("Sem cliente").tag(Optional<String>.none)
                            ForEach(customers) { c in
                                Text(c.name ?? "Sem nome").tag(Optional(c.id))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))

                    // Forma de pagamento
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        Text("Forma de pagamento")
                            .font(.system(size: AppTheme.FontSize.title3, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Picker("Pagamento", selection: $paymentMethod) {
                            ForEach(paymentOptions, id: \.id) { opt in
                                Text(opt.label).tag(opt.id)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))

                    // Desconto
                    HStack {
                        Text("Desconto (R$)")
                            .font(.system(size: AppTheme.FontSize.body, weight: .medium))
                            .foregroundStyle(AppTheme.textPrimary)
                        TextField("0,00", text: $discount)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))

                    // Resumo
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        HStack {
                            Text("Subtotal")
                                .foregroundStyle(AppTheme.textSecondary)
                            Spacer()
                            Text(formatCurrency(subtotal))
                                .font(.system(size: AppTheme.FontSize.body, weight: .medium))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        HStack {
                            Text("Desconto")
                                .foregroundStyle(AppTheme.textSecondary)
                            Spacer()
                            Text("- \(formatCurrency(discountValue))")
                                .font(.system(size: AppTheme.FontSize.body, weight: .medium))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        Divider()
                        HStack {
                            Text("Total")
                                .font(.system(size: AppTheme.FontSize.title3, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Text(formatCurrency(total))
                                .font(.system(size: AppTheme.FontSize.title3, weight: .bold))
                                .foregroundStyle(AppTheme.primary)
                        }
                    }
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))

                    Button {
                        Task { await submitSale() }
                    } label: {
                        HStack(spacing: AppTheme.Spacing.sm) {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Finalizar venda")
                                    .font(.system(size: AppTheme.FontSize.body, weight: .semibold))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Spacing.md)
                        .background(cartItems.isEmpty ? AppTheme.textTertiary : AppTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                    }
                    .disabled(cartItems.isEmpty || isSubmitting)
                }
                .padding()
            }
            .background(AppTheme.background)
            .navigationTitle("Nova venda")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .sheet(isPresented: $showProductPicker) {
                ProductPickerSheet { product in
                    addProduct(product)
                }
            }
            .sheet(isPresented: $showQuickCustomerSheet) {
                QuickCustomerSheet(onCreated: { customer in
                    if !customers.contains(where: { $0.id == customer.id }) {
                        customers.append(customer)
                    } else if let idx = customers.firstIndex(where: { $0.id == customer.id }) {
                        customers[idx] = customer
                    }
                    selectedCustomerId = customer.id
                    showQuickCustomerSheet = false
                })
            }
            .task { await loadCustomers() }
        }
        .onChange(of: successSaleId) { _, newId in
            if newId != nil {
                onSaleCreated?()
                dismiss()
            }
        }
    }

    private func addProduct(_ product: Product) {
        let id = product.id
        let price = product.price ?? 0
        if let idx = cartItems.firstIndex(where: { $0.productId == id }) {
            let qty = cartItems[idx].quantity + 1
            cartItems[idx] = CartItem(
                productId: id,
                productName: product.name,
                unitPrice: price,
                quantity: qty,
                subtotal: price * Double(qty)
            )
        } else {
            cartItems.append(CartItem(
                productId: id,
                productName: product.name,
                unitPrice: price,
                quantity: 1,
                subtotal: price
            ))
        }
    }

    private func updateQuantity(for productId: String, quantity: Double) {
        guard let idx = cartItems.firstIndex(where: { $0.productId == productId }),
              quantity > 0 else { return }
        let item = cartItems[idx]
        cartItems[idx] = CartItem(
            productId: item.productId,
            productName: item.productName,
            unitPrice: item.unitPrice,
            quantity: quantity,
            subtotal: item.unitPrice * quantity
        )
    }

    private func removeItem(productId: String) {
        cartItems.removeAll { $0.productId == productId }
    }

    private func loadCustomers() async {
        do {
            customers = try await api.getCustomers()
        } catch {
            customers = []
        }
    }

    private func submitSale() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        let payload = CreateSalePayload(
            items: cartItems.map {
                CreateSaleItemPayload(
                    productId: $0.productId,
                    quantity: $0.quantity,
                    unitPrice: $0.unitPrice,
                    subtotal: $0.subtotal
                )
            },
            subtotal: subtotal,
            discount: discountValue,
            total: total,
            paymentMethod: paymentMethod,
            customerId: selectedCustomerId.flatMap { id in customers.first(where: { $0.id == id })?.id },
            customerName: selectedCustomerId.flatMap { id in customers.first(where: { $0.id == id })?.name },
            customerDocument: selectedCustomerId.flatMap { id in customers.first(where: { $0.id == id })?.document },
            shouldEmitNFe: false
        )

        do {
            let res = try await api.postCreateSale(payload: payload)
            successSaleId = res.id
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "pt_BR")
        return f.string(from: NSNumber(value: value)) ?? "R$ 0,00"
    }
}

// MARK: - Cart item model

private struct CartItem: Identifiable {
    let productId: String
    let productName: String
    let unitPrice: Double
    var quantity: Double
    var subtotal: Double
    var id: String { productId }
}

// MARK: - Cart row

private struct CartItemRow: View {
    let item: CartItem
    let onQuantityChange: (Double) -> Void
    let onRemove: () -> Void

    @State private var qtyText: String = ""

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.productName)
                    .font(.system(size: AppTheme.FontSize.body, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(formatCurrency(item.unitPrice) + " × \(Int(item.quantity))")
                    .font(.system(size: AppTheme.FontSize.caption))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            HStack(spacing: AppTheme.Spacing.xs) {
                Button {
                    let new = max(1, item.quantity - 1)
                    onQuantityChange(new)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.primary)
                }
                Text("\(Int(item.quantity))")
                    .font(.system(size: AppTheme.FontSize.callout, weight: .semibold))
                    .frame(minWidth: 28, alignment: .center)
                Button {
                    onQuantityChange(item.quantity + 1)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.primary)
                }
            }
            Text(formatCurrency(item.subtotal))
                .font(.system(size: AppTheme.FontSize.callout, weight: .bold))
                .foregroundStyle(AppTheme.primary)
                .frame(width: 72, alignment: .trailing)
            Button {
                onRemove()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.error)
            }
        }
        .padding(.vertical, AppTheme.Spacing.sm)
        .padding(.horizontal, AppTheme.Spacing.sm)
        .background(AppTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
    }

    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "pt_BR")
        return f.string(from: NSNumber(value: value)) ?? "R$ 0,00"
    }
}

// MARK: - Quick Customer Sheet (cadastrar na hora da venda)

private struct QuickCustomerSheet: View {
    let onCreated: (Customer) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var document = ""
    @State private var phone = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    private let api = ApiClient.shared

    var body: some View {
        NavigationStack {
            Form {
                if let msg = errorMessage {
                    Section {
                        HStack(spacing: AppTheme.Spacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(AppTheme.error)
                            Text(msg)
                                .font(.system(size: AppTheme.FontSize.caption))
                                .foregroundStyle(AppTheme.error)
                        }
                    }
                }
                Section {
                    TextField("Nome", text: $name)
                        .textContentType(.name)
                        .autocapitalization(.words)
                    TextField("CPF ou CNPJ", text: $document)
                        .keyboardType(.numberPad)
                        .textContentType(.username)
                    TextField("Telefone (opcional)", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                } header: {
                    Text("Dados do cliente")
                } footer: {
                    Text("Nome e documento (CPF/CNPJ) são obrigatórios.")
                }
            }
            .navigationTitle("Cadastrar cliente")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Salvar")
                        }
                    }
                    .disabled(isSubmitting || name.trimmingCharacters(in: .whitespaces).isEmpty || document.trimmingCharacters(in: .whitespaces).count < 11)
                }
            }
        }
    }

    private func submit() async {
        let n = name.trimmingCharacters(in: .whitespaces)
        let d = document.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        let p = phone.trimmingCharacters(in: .whitespaces).isEmpty ? nil : phone.trimmingCharacters(in: .whitespaces)

        guard !n.isEmpty else {
            errorMessage = "Nome é obrigatório"
            return
        }
        guard d.count >= 11 else {
            errorMessage = "CPF (11 dígitos) ou CNPJ (14 dígitos) é obrigatório"
            return
        }

        isSubmitting = true
        errorMessage = nil
        do {
            let customer = try await api.createCustomer(name: n, document: d, phone: p)
            onCreated(customer)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}

#Preview {
    NewSaleScreen()
}
