import SwiftUI

struct ProductPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (Product) -> Void

    @State private var products: [Product] = []
    @State private var searchText = ""
    @State private var isLoading = true

    private var filteredProducts: [Product] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return products }
        return products.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
                || ($0.sku?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: AppTheme.Spacing.md) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(AppTheme.primary)
                        Text("Carregando produtos...")
                            .font(.system(size: AppTheme.FontSize.callout))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredProducts) { product in
                            Button {
                                onSelect(product)
                                dismiss()
                            } label: {
                                ProductPickerRow(product: product)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(AppTheme.background)
            .searchable(text: $searchText, prompt: "Buscar produto ou SKU")
            .navigationTitle("Adicionar produto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .task { await loadProducts() }
        }
    }

    private func loadProducts() async {
        isLoading = true
        do {
            products = try await ApiClient.shared.getProducts()
        } catch {
            products = []
        }
        isLoading = false
    }
}

// MARK: - ProductPickerRow

private struct ProductPickerRow: View {
    let product: Product

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "shippingbox.fill")
                .font(.title3)
                .foregroundStyle(AppTheme.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(.system(size: AppTheme.FontSize.body, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                if let sku = product.sku, !sku.isEmpty {
                    Text("SKU: \(sku)")
                        .font(.system(size: AppTheme.FontSize.caption))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            Spacer()
            Text(formatCurrency(product.price ?? 0))
                .font(.system(size: AppTheme.FontSize.callout, weight: .semibold))
                .foregroundStyle(AppTheme.primary)
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textTertiary)
        }
        .padding(.vertical, AppTheme.Spacing.xs)
    }

    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "pt_BR")
        return f.string(from: NSNumber(value: value)) ?? "R$ 0,00"
    }
}
