//
//  MainTabView.swift
//  Reverie
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 0: Today — home screen with cognitive load + resilience signals
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "house.fill")
                }
                .tag(0)

            // Tab 1: Domains + Goals — combined life area organisation
            DomainsAndGoalsView()
                .tabItem {
                    Label("Domains", systemImage: "square.grid.2x2")
                }
                .tag(1)

            // Tab 2: Lumina — conversational AI companion
            LuminaView()
                .tabItem {
                    Label("Lumina", systemImage: "brain.head.profile")
                }
                .tag(2)

            // Tab 3: Resilience Index — wellbeing + academic performance analytics
            AnalyticsDashboardView()
                .tabItem {
                    Label("Resilience", systemImage: "waveform.path.ecg.rectangle")
                }
                .tag(3)

            // Tab 4: More — settings, tools, anchors
            MoreView()
                .tabItem {
                    Label("More", systemImage: "ellipsis.circle.fill")
                }
                .tag(4)
        }
        .accentColor(DSColors.accentPrimary)
        .onAppear {
            setupTabSwitchNotification()
        }
    }

    private func setupTabSwitchNotification() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SwitchToTab"),
            object: nil,
            queue: .main
        ) { notification in
            if let tabIndex = notification.userInfo?["tabIndex"] as? Int {
                withAnimation {
                    selectedTab = tabIndex
                }
            }
        }
    }
}
