//
//  ContentView.swift
//  RfidApp
//

import SwiftUI

struct ContentView: View {
    @StateObject private var auth = AuthService.shared

    var body: some View {
        Group {
            if auth.isLoggedIn, auth.currentUser != nil {
                MainTabView(auth: auth)
            } else {
                LoginView(auth: auth)
            }
        }
    }
}

#Preview {
    ContentView()
}
