import SwiftUI

struct CategoriesScreen: View {
    @State private var categories: [Category] = []
    @State private var searchTerm = ""
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showAddSheet = false
    @State private var editingCategory: Category?
    @State private var showDeleteAlert = false
    @State private var categoryToDelete: Category?
    private let api = ApiClient.shared

    private var filteredCategories: [Category] {
        guard !searchTerm.isEmpty else { return categories }
        let term = searchTerm.lowercased()
        return categories.filter { ($0.name ?? "").lowercased().contains(term) }
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

            // Busca
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.textTertiary)
                TextField("Buscar categorias...", text: $searchTerm)
                    .textFieldStyle(.plain)
            }
            .padding(AppTheme.Spacing.md)

            List {
                ForEach(filteredCategories) { c in
                    HStack(spacing: AppTheme.Spacing.md) {
                        Image(systemName: "folder.fill")
                            .font(.title3)
                            .foregroundStyle(AppTheme.primary)
                        Text(c.name ?? "Sem nome")
                            .font(.system(size: AppTheme.FontSize.body, weight: .medium))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Button {
                            editingCategory = c
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.primary)
                        }
                        Button {
                            categoryToDelete = c
                            showDeleteAlert = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.error)
                        }
                    }
                    .padding(.vertical, AppTheme.Spacing.xs)
                }
            }
            .listStyle(.plain)
            .refreshable { await load() }
        }
        .navigationTitle("Categorias")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editingCategory = nil
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .task { await load() }
        .sheet(isPresented: $showAddSheet) {
            CategoryFormSheet(
                category: nil,
                onDismiss: {
                    showAddSheet = false
                },
                onSuccess: {
                    showAddSheet = false
                    Task { await load() }
                }
            )
        }
        .sheet(item: $editingCategory) { cat in
            CategoryFormSheet(
                category: cat,
                onDismiss: { editingCategory = nil },
                onSuccess: {
                    editingCategory = nil
                    Task { await load() }
                }
            )
        }
        .alert("Excluir categoria?", isPresented: $showDeleteAlert) {
            Button("Cancelar", role: .cancel) {
                categoryToDelete = nil
            }
            Button("Excluir", role: .destructive) {
                if let c = categoryToDelete {
                    Task { await deleteCategory(c) }
                }
                categoryToDelete = nil
            }
        } message: {
            Text("Tem certeza que deseja excluir esta categoria?")
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            categories = try await api.getCategories()
        } catch {
            errorMessage = error.localizedDescription
            categories = []
        }
        isLoading = false
    }

    private func deleteCategory(_ c: Category) async {
        do {
            try await api.deleteCategory(id: c.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct CategoryFormSheet: View {
    let category: Category?
    let onDismiss: () -> Void
    let onSuccess: () -> Void

    @State private var name: String = ""
    @State private var isLoading = false
    @State private var errorMsg: String?
    private let api = ApiClient.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("Nome") {
                    TextField("Nome da categoria", text: $name)
                }
                if let msg = errorMsg {
                    Section {
                        Text(msg)
                            .foregroundStyle(AppTheme.error)
                    }
                }
            }
            .navigationTitle(category == nil ? "Nova Categoria" : "Editar Categoria")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        Task { await submit() }
                    }
                    .disabled(isLoading || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear {
            name = category?.name ?? ""
        }
    }

    private func submit() async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        errorMsg = nil
        do {
            if let c = category {
                try await api.updateCategory(id: c.id, name: trimmed)
            } else {
                _ = try await api.createCategory(name: trimmed)
            }
            onSuccess()
        } catch {
            errorMsg = error.localizedDescription
        }
        isLoading = false
    }
}
