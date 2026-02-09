import SwiftUI

struct CadastrarTagScreen: View {
    @Environment(\.dismiss) private var dismiss
    let product: Product
    var onSaved: (() -> Void)?

    @StateObject private var bt = RfidBluetoothManager.shared
    @State private var rfidInput = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @FocusState private var fieldFocused: Bool

    private let api = ApiClient.shared

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            // Produto
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.primary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.system(size: AppTheme.FontSize.title3, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    if let sku = product.sku, !sku.isEmpty {
                        Text("SKU: \(sku)")
                            .font(.system(size: AppTheme.FontSize.caption))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                Spacer()
            }
            .padding(AppTheme.Spacing.lg)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
            .padding(.horizontal)

            // Erro
            if let msg = errorMessage {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppTheme.error)
                    Text(msg)
                        .font(.system(size: AppTheme.FontSize.caption))
                        .foregroundStyle(AppTheme.error)
                }
                .frame(maxWidth: .infinity)
                .padding(AppTheme.Spacing.md)
                .background(AppTheme.error.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                .padding(.horizontal)
            }

            // Campo RFID
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text("Tag RFID (EPC)")
                    .font(.system(size: AppTheme.FontSize.footnote, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Text("Digite/cole manualmente ou conecte o leitor em \"Escanear RFID\" e escaneie – o código aparece aqui sozinho.")
                    .font(.system(size: AppTheme.FontSize.caption))
                    .foregroundStyle(AppTheme.textTertiary)
                HStack(spacing: AppTheme.Spacing.sm) {
                    TextField("Ex: E20012345678901234567890", text: $rfidInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .focused($fieldFocused)
                        .submitLabel(.done)
                        .onSubmit { save() }
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Salvar")
                                .font(.system(size: AppTheme.FontSize.body, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(minWidth: 80, minHeight: 44)
                    .background(canSave ? AppTheme.primary : AppTheme.textTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
                    .disabled(!canSave || isSaving)
                }
            }
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
            .padding(.horizontal)

            // Conexão BLE (opcional)
            if bt.isConnected {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.success)
                    Text("Leitor conectado – aponte e escaneie a tag, o código vem automaticamente")
                        .font(.system(size: AppTheme.FontSize.caption))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
        .navigationTitle("Cadastrar tag RFID")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Fechar") { dismiss() }
            }
        }
        .onAppear {
            fieldFocused = true
            bt.onTagRead = { tag in
                let t = tag.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                DispatchQueue.main.async {
                    rfidInput = t
                    save()
                }
            }
        }
        .onDisappear {
            bt.onTagRead = nil
        }
        .alert("Tag cadastrada", isPresented: $showSuccess) {
            Button("OK") {
                onSaved?()
                dismiss()
            }
        } message: {
            Text("A tag RFID foi vinculada ao produto com sucesso.")
        }
    }

    private var canSave: Bool {
        !rfidInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        let tag = rfidInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty, !isSaving else { return }

        errorMessage = nil
        isSaving = true

        Task {
            do {
                try await api.updateProductRfidTag(product: product, rfidTag: tag)
                await MainActor.run {
                    isSaving = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
