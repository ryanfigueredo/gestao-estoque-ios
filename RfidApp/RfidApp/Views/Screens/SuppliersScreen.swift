import SwiftUI

struct SuppliersScreen: View {
    @State private var suppliers: [Supplier] = []
    @State private var errorMessage: String?
    @State private var searchText = ""
    private let api = ApiClient.shared

    var filtered: [Supplier] {
        if searchText.isEmpty { return suppliers }
        return suppliers.filter {
            ($0.name ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.document ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.phone ?? "").localizedCaseInsensitiveContains(searchText)
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
            List {
                ForEach(filtered) { s in
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Text(s.name ?? "Sem nome")
                            .font(.system(size: AppTheme.FontSize.body, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        if let doc = s.document, !doc.isEmpty {
                            Text("CNPJ: \(doc)")
                                .font(.system(size: AppTheme.FontSize.caption))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        if let ph = s.phone, !ph.isEmpty {
                            Text(ph)
                                .font(.system(size: AppTheme.FontSize.footnote))
                                .foregroundStyle(AppTheme.primary)
                        }
                    }
                    .padding(.vertical, AppTheme.Spacing.xs)
                }
            }
            .listStyle(.plain)
            .refreshable { await load() }
        }
        .navigationTitle("Fornecedores")
        .searchable(text: $searchText, prompt: "Buscar por nome ou CNPJ")
        .task { await load() }
    }

    private func load() async {
        errorMessage = nil
        do {
            suppliers = try await api.getSuppliers()
        } catch {
            errorMessage = error.localizedDescription
            suppliers = []
        }
    }
}
