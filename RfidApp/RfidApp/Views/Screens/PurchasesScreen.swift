import SwiftUI

struct PurchasesScreen: View {
    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Image(systemName: "cart.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.textTertiary)
            Text("Compras")
                .font(.system(size: AppTheme.FontSize.title2, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("Gestão de compras disponível no sistema web.")
                .font(.system(size: AppTheme.FontSize.body))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
        .navigationTitle("Compras")
    }
}
