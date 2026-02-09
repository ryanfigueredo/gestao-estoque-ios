import SwiftUI

struct ProductOptionsSheet: View {
    let product: Product
    let onEncontrar: () -> Void
    let onCadastrarTag: () -> Void
    let onDismiss: () -> Void

    var hasRfid: Bool {
        (product.rfidTag?.trimmingCharacters(in: .whitespaces).isEmpty ?? true) == false
    }

    var body: some View {
        NavigationStack {
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
                        if let sku = product.sku { Text("SKU: \(sku)").font(.caption).foregroundStyle(AppTheme.textSecondary) }
                    }
                    Spacer()
                }
                .padding(AppTheme.Spacing.lg)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
                .padding(.horizontal)

                Text("O que deseja fazer?")
                    .font(.system(size: AppTheme.FontSize.callout, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                // Encontrar produto ou Cadastrar tag
                Button(action: hasRfid ? onEncontrar : onCadastrarTag) {
                    HStack(spacing: AppTheme.Spacing.md) {
                        Image(systemName: hasRfid ? "magnifyingglass" : "tag.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(AppTheme.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(hasRfid ? "Encontrar produto" : "Cadastrar tag RFID")
                                .font(.system(size: AppTheme.FontSize.body, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(hasRfid
                                 ? "O leitor RFID apita quando chegar perto deste produto"
                                 : "Produto sem tag – cadastre a tag para localizar depois")
                                .font(.system(size: AppTheme.FontSize.caption))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    .padding(AppTheme.Spacing.lg)
                    .background(AppTheme.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                }
                .buttonStyle(.plain)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, AppTheme.Spacing.lg)
            .background(AppTheme.background)
            .navigationTitle("Opções")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { onDismiss() }
                }
            }
        }
    }
}
