//
//  RfidAppApp.swift
//  RfidApp
//

import SwiftUI

@main
struct RfidAppApp: App {
    init() {
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(TenantBrandingService.shared)
        }
    }

    private func configureAppearance() {
        UINavigationBar.appearance().largeTitleTextAttributes = [
            .foregroundColor: UIColor(AppTheme.textPrimary)
        ]
        UINavigationBar.appearance().titleTextAttributes = [
            .foregroundColor: UIColor(AppTheme.textPrimary)
        ]
    }
}
