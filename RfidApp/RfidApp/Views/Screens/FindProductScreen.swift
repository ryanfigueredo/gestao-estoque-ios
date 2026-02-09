import SwiftUI
import AudioToolbox

struct FindProductScreen: View {
    @Environment(\.dismiss) private var dismiss
    let product: Product
    @StateObject private var bt = RfidBluetoothManager.shared
    @State private var isSearching = false
    @State private var found = false
    @State private var lastReadTag: String?
    @State private var scanInput = ""
    @FocusState private var scanFieldFocused: Bool

    private var targetTag: String? {
        product.rfidTag?.trimmingCharacters(in: .whitespaces).isEmpty == false
            ? product.rfidTag?.trimmingCharacters(in: .whitespaces)
            : nil
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            // Produto que estamos procurando
            VStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: found ? "checkmark.circle.fill" : "magnifyingglass")
                    .font(.system(size: 56))
                    .foregroundStyle(found ? AppTheme.success : AppTheme.primary)
                Text(product.name)
                    .font(.system(size: AppTheme.FontSize.title2, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                if let sku = product.sku, !sku.isEmpty {
                    Text("SKU: \(sku)")
                        .font(.system(size: AppTheme.FontSize.caption))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                if let tag = targetTag {
                    Text("Tag: \(tag)")
                        .font(.system(size: AppTheme.FontSize.caption, design: .monospaced))
                        .foregroundStyle(AppTheme.textTertiary)
                        .lineLimit(2)
                }
            }
            .padding(AppTheme.Spacing.lg)
            .frame(maxWidth: .infinity)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
            .padding(.horizontal)

            if targetTag == nil {
                VStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title)
                        .foregroundStyle(AppTheme.warning)
                    Text("Produto sem tag RFID cadastrada")
                        .font(.system(size: AppTheme.FontSize.body))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(AppTheme.Spacing.lg)
            } else {
                if found {
                    VStack(spacing: AppTheme.Spacing.sm) {
                        Text("Produto encontrado!")
                            .font(.system(size: AppTheme.FontSize.title3, weight: .bold))
                            .foregroundStyle(AppTheme.success)
                        Text("O leitor detectou a tag RFID deste produto.")
                            .font(.system(size: AppTheme.FontSize.caption))
                            .foregroundStyle(AppTheme.textSecondary)
                        Button("Buscar novamente") {
                            found = false
                            isSearching = true
                            startListening()
                        }
                        .font(.system(size: AppTheme.FontSize.body, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        .padding(.vertical, AppTheme.Spacing.sm)
                        .background(AppTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                    }
                    .padding(AppTheme.Spacing.lg)
                } else {
                    VStack(spacing: AppTheme.Spacing.md) {
                        Text(isSearching
                             ? "Aponte o leitor na direção dos produtos. Ele apitará quando encontrar."
                             : "Toque em Iniciar e aponte o leitor. O app vibrará e emitirá som ao encontrar.")
                            .font(.system(size: AppTheme.FontSize.body))
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button {
                            if isSearching {
                                isSearching = false
                                bt.onTagRead = nil
                            } else {
                                isSearching = true
                                startListening()
                            }
                        } label: {
                            HStack(spacing: AppTheme.Spacing.sm) {
                                if isSearching {
                                    ProgressView()
                                        .tint(.white)
                                    Text("Buscando...")
                                } else {
                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                    Text("Iniciar busca")
                                }
                            }
                            .font(.system(size: AppTheme.FontSize.body, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppTheme.Spacing.md)
                            .background(isSearching ? AppTheme.textSecondary : AppTheme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                        }
                        .disabled(targetTag == nil)
                    }
                    .padding(AppTheme.Spacing.lg)

                    // Leitura manual (fallback)
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        Text("Ou escaneie manualmente")
                            .font(.system(size: AppTheme.FontSize.footnote, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                        HStack(spacing: AppTheme.Spacing.sm) {
                            TextField("EPC da tag", text: $scanInput)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                                .focused($scanFieldFocused)
                                .onSubmit { checkManualTag() }
                            Button("Verificar") {
                                checkManualTag()
                            }
                            .font(.system(size: AppTheme.FontSize.body, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, AppTheme.Spacing.md)
                            .padding(.vertical, AppTheme.Spacing.sm)
                            .background(AppTheme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
                        }
                    }
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                    .padding(.horizontal)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
        .navigationTitle("Encontrar produto")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Fechar") { dismiss() }
            }
        }
        .onAppear {
            // Nada - startListening é chamado ao tocar Iniciar busca
        }
        .onDisappear {
            bt.onTagRead = nil
            isSearching = false
        }
    }

    private func startListening() {
        guard let tag = targetTag else { return }
        bt.onTagRead = { readTag in
            let normalized = readTag.trimmingCharacters(in: .whitespacesAndNewlines)
            let target = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalized.localizedCaseInsensitiveCompare(target) == .orderedSame
                || normalized.hasSuffix(target)
                || target.hasSuffix(normalized) {
                DispatchQueue.main.async {
                    triggerFound()
                }
            }
        }
    }

    private func triggerFound() {
        guard !found else { return }
        found = true
        isSearching = false
        bt.onTagRead = nil

        // Vibração
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let g2 = UINotificationFeedbackGenerator()
            g2.notificationOccurred(.success)
        }

        // Som (beep de sucesso)
        AudioServicesPlaySystemSound(1057) // Tock
    }

    private func checkManualTag() {
        let t = scanInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, let target = targetTag else { return }
        let normalized = t.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetNorm = target.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.localizedCaseInsensitiveCompare(targetNorm) == .orderedSame
            || normalized.hasSuffix(targetNorm)
            || targetNorm.hasSuffix(normalized) {
            scanInput = ""
            triggerFound()
        } else {
            // Tag diferente - feedback de "não é esse"
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        }
    }
}
