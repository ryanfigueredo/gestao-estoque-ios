import SwiftUI

struct ProductsScreen: View {
    @State private var products: [Product] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var showScanScreen = false
    @State private var selectedProductForOptions: Product?
    @State private var selectedProductForFind: Product?
    @State private var selectedProductForCadastrarTag: Product?
    private let api = ApiClient.shared

    var filteredProducts: [Product] {
        let list = products.filter { ($0.stock ?? 0) >= 0 }
        if searchText.isEmpty { return list }
        return list.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.sku?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            ($0.rfidTag?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            ($0.barcode?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
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

            // Botão Escanear RFID
            Button {
                showScanScreen = true
            } label: {
                HStack(spacing: AppTheme.Spacing.md) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 22))
                        .foregroundStyle(AppTheme.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Escanear RFID")
                            .font(.system(size: AppTheme.FontSize.body, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Auditoria com leitor UHF")
                            .font(.system(size: AppTheme.FontSize.caption))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .padding(AppTheme.Spacing.md)
                .background(AppTheme.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)

            List {
                ForEach(filteredProducts) { p in
                    Button {
                        selectedProductForOptions = p
                    } label: {
                        HStack(spacing: AppTheme.Spacing.md) {
                            Image(systemName: "barcode.viewfinder")
                                .font(.title2)
                                .foregroundStyle(AppTheme.primary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name)
                                    .font(.system(size: AppTheme.FontSize.body, weight: .semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                if let sku = p.sku, !sku.isEmpty {
                                    Text("SKU: \(sku)")
                                        .font(.system(size: AppTheme.FontSize.caption))
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                if let price = p.price {
                                    Text(formatCurrency(price))
                                        .font(.system(size: AppTheme.FontSize.callout, weight: .semibold))
                                        .foregroundStyle(AppTheme.primary)
                                }
                                if let stock = p.stock {
                                    Text("Est: \(Int(stock))")
                                        .font(.system(size: AppTheme.FontSize.caption))
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                            }
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        .padding(.vertical, AppTheme.Spacing.xs)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            selectedProductForFind = p
                        } label: {
                            Label("Encontrar produto", systemImage: "magnifyingglass")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .refreshable { await load() }
        }
        .navigationTitle("Produtos")
        .searchable(text: $searchText, prompt: "Nome, SKU ou RFID")
        .sheet(isPresented: $showScanScreen) {
            NavigationStack {
                ProductScanScreen()
            }
        }
        .sheet(item: $selectedProductForOptions) { product in
            ProductOptionsSheet(
                product: product,
                onEncontrar: {
                    selectedProductForOptions = nil
                    selectedProductForFind = product
                },
                onCadastrarTag: {
                    selectedProductForOptions = nil
                    selectedProductForCadastrarTag = product
                },
                onDismiss: {
                    selectedProductForOptions = nil
                }
            )
        }
        .sheet(item: $selectedProductForFind) { product in
            NavigationStack {
                FindProductScreen(product: product)
            }
        }
        .sheet(item: $selectedProductForCadastrarTag) { product in
            NavigationStack {
                CadastrarTagScreen(product: product) {
                    selectedProductForCadastrarTag = nil
                    Task { await load() }
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            products = try await api.getProducts()
        } catch {
            errorMessage = error.localizedDescription
            products = []
        }
        isLoading = false
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: value)) ?? "R$ 0,00"
    }
}
