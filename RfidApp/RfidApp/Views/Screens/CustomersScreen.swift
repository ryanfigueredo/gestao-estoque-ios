import SwiftUI

struct CustomersScreen: View {
    @State private var customers: [Customer] = []
    @State private var errorMessage: String?
    @State private var searchText = ""
    private let api = ApiClient.shared

    var filtered: [Customer] {
        if searchText.isEmpty { return customers }
        return customers.filter {
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
                ForEach(filtered) { c in
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Text(c.name ?? "Sem nome")
                            .font(.system(size: AppTheme.FontSize.body, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        if let doc = c.document, !doc.isEmpty {
                            Text("Doc: \(doc)")
                                .font(.system(size: AppTheme.FontSize.caption))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        if let ph = c.phone, !ph.isEmpty {
                            Text(ph)
                                .font(.system(size: AppTheme.FontSize.footnote))
                                .foregroundStyle(AppTheme.primary)
                        }
                        if let em = c.email, !em.isEmpty {
                            Text(em)
                                .font(.system(size: AppTheme.FontSize.footnote))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                    }
                    .padding(.vertical, AppTheme.Spacing.xs)
                }
            }
            .listStyle(.plain)
            .refreshable { await load() }
        }
        .navigationTitle("Clientes")
        .searchable(text: $searchText, prompt: "Buscar por nome, documento ou telefone")
        .task { await load() }
    }

    private func load() async {
        errorMessage = nil
        do {
            customers = try await api.getCustomers()
        } catch {
            errorMessage = error.localizedDescription
            customers = []
        }
    }
}
