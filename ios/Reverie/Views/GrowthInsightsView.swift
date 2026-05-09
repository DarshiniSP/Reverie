//
//  GrowthInsightsView.swift
//  iAlly
//
//  Created on 9/12/2025.
//

import SwiftUI
import SwiftData

struct GrowthInsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GrowthInsight.generatedDate, order: .reverse)
    private var allInsights: [GrowthInsight]
    
    @State private var selectedType: InsightTypeFilter = .all
    
    enum InsightTypeFilter: String, CaseIterable {
        case all = "All"
        case timePattern = "Time"
        case energyPattern = "Energy"
        case recoveryPattern = "Recovery"
        case motivational = "Motivational"
        case warning = "Warning"
        
        var systemImage: String {
            switch self {
            case .all: return "sparkles"
            case .timePattern: return "clock"
            case .energyPattern: return "bolt.fill"
            case .recoveryPattern: return "arrow.uturn.forward.circle.fill"
            case .motivational: return "star.fill"
            case .warning: return "exclamationmark.triangle"
            }
        }
    }
    
    private var filteredInsights: [GrowthInsight] {
        if selectedType == .all {
            return allInsights
        }
        return allInsights.filter { insight in
            switch selectedType {
            case .timePattern:
                return insight.insightType == .timePattern
            case .energyPattern:
                return insight.insightType == .energyPattern
            case .recoveryPattern:
                return insight.insightType == .recoveryPattern
            case .motivational:
                return insight.insightType == .motivational
            case .warning:
                return insight.insightType == .warning
            case .all:
                return true
            }
        }
    }
    
    private var unreadCount: Int {
        allInsights.filter { !$0.isRead }.count
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Type Filter Picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(InsightTypeFilter.allCases, id: \.self) { type in
                            filterButton(for: type)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(DSColors.canvasPrimary)
                
                Divider()
                
                if filteredInsights.isEmpty {
                    // Empty State
                    VStack(spacing: 16) {
                        Image(systemName: "chart.line.uptrend.xyaxis.circle")
                            .font(.system(size: 64))
                            .foregroundColor(DSColors.textSecondary)
                        
                        Text("Keep going!")
                            .font(DSFonts.title())
                            .foregroundColor(DSColors.textPrimary)
                        
                        Text("Insights appear after tracking patterns.\nComplete tasks, maintain routines, and learn from setbacks.")
                            .font(DSFonts.body())
                            .foregroundColor(DSColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DSColors.canvasPrimary)
                } else {
                    // Insights List
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredInsights) { insight in
                                InsightCard(insight: insight) {
                                    markAsRead(insight)
                                }
                            }
                        }
                        .padding()
                    }
                    .background(DSColors.canvasPrimary)
                }
            }
            .navigationTitle("Growth Insights")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if unreadCount > 0 {
                        Button {
                            markAllAsRead()
                        } label: {
                            Text("Mark All Read")
                                .font(DSFonts.body(14))
                        }
                    }
                }
            }
        }
    }
    
    private func filterButton(for type: InsightTypeFilter) -> some View {
        Button {
            selectedType = type
        } label: {
            Label(type.rawValue, systemImage: type.systemImage)
                .font(DSFonts.body(14))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(selectedType == type ? DSColors.accentPrimary : DSColors.canvasSecondary)
                .foregroundColor(selectedType == type ? DSColors.onAccent : DSColors.textPrimary)
                .cornerRadius(UIConstants.CornerRadius.round)
        }
    }
    
    private func markAsRead(_ insight: GrowthInsight) {
        insight.isRead = true
        try? modelContext.save()
    }
    
    private func markAllAsRead() {
        for insight in allInsights where !insight.isRead {
            insight.isRead = true
        }
        try? modelContext.save()
    }
}

struct InsightCard: View {
    let insight: GrowthInsight
    let onMarkRead: () -> Void
    
    var body: some View {
        Card(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: insight.insightType.icon)
                        .font(DSFonts.headline())
                        .foregroundColor(Color(insight.insightType.color))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(insight.insightText)
                            .font(DSFonts.body())
                            .foregroundColor(DSColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        HStack(spacing: 12) {
                            // Confidence Indicator
                            HStack(spacing: 4) {
                                Image(systemName: "chart.bar.fill")
                                    .font(DSFonts.caption())
                                Text("\(Int(insight.confidenceScore * 100))% confident")
                                    .font(DSFonts.caption())
                            }
                            .foregroundColor(confidenceColor(insight.confidenceScore))
                            
                            Text("•")
                                .foregroundColor(DSColors.textSecondary)
                            
                            // Date
                            Text(insight.generatedDate.formatted(date: .abbreviated, time: .omitted))
                                .font(DSFonts.caption())
                                .foregroundColor(DSColors.textSecondary)
                            
                            Spacer()
                            
                            // Unread Badge
                            if !insight.isRead {
                                Circle()
                                    .fill(DSColors.accentPrimary)
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                }
                
                // Related Events Count
                if let events = insight.relatedEvents, !events.isEmpty {
                    Text("Based on \(events.count) \(events.count == 1 ? "event" : "events")")
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.textSecondary)
                        .padding(.leading, 32)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !insight.isRead {
                onMarkRead()
            }
        }
    }
    
    private func confidenceColor(_ score: Double) -> Color {
        if score >= 0.8 {
            return DSColors.success
        } else if score >= 0.6 {
            return DSColors.accentPrimary
        } else {
            return DSColors.warning
        }
    }
}

#Preview {
    GrowthInsightsView()
        .modelContainer(for: [GrowthInsight.self, MindsetEvent.self])
}
