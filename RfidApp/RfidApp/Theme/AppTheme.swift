import SwiftUI

enum AppTheme {
    // MARK: - Colors (laranja/âmbar - alinhado ao desktop Estoque Inteligente)
    static let primary = Color(red: 0.961, green: 0.620, blue: 0.043)       // amber-500
    static let primaryLight = Color(red: 0.984, green: 0.749, blue: 0.141) // amber-400
    static let primaryDark = Color(red: 0.851, green: 0.467, blue: 0.024)  // amber-600
    
    static let success = Color(red: 0.063, green: 0.725, blue: 0.506)
    static let error = Color(red: 0.937, green: 0.267, blue: 0.267)
    static let warning = Color(red: 0.961, green: 0.620, blue: 0.043)
    
    static let background = Color(red: 0.969, green: 0.973, blue: 0.980)
    static let surface = Color.white
    static let surfaceSecondary = Color(red: 0.973, green: 0.976, blue: 0.980)
    
    static let textPrimary = Color(red: 0.067, green: 0.094, blue: 0.153)
    static let textSecondary = Color(red: 0.420, green: 0.447, blue: 0.502)
    static let textTertiary = Color(red: 0.616, green: 0.639, blue: 0.678)
    
    static let border = Color(red: 0.878, green: 0.906, blue: 0.937)
    static let shadow = Color.black.opacity(0.08)
    
    // MARK: - Typography
    enum FontSize {
        static let largeTitle: CGFloat = 28
        static let title1: CGFloat = 22
        static let title2: CGFloat = 18
        static let title3: CGFloat = 16
        static let body: CGFloat = 15
        static let callout: CGFloat = 14
        static let caption: CGFloat = 12
        static let footnote: CGFloat = 11
    }
    
    // MARK: - Spacing
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 40
    }
    
    // MARK: - Radius
    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let full: CGFloat = 999
    }
}
