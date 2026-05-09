//
//  CustomViewsListView.swift
//  iAlly
//
//  Created on 12/12/2025.
//

import SwiftUI
import SwiftData

struct CustomViewsListView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \CustomView.createdAt) private var customViews: [CustomView]
    
    @State private var showingAddView = false
    @State private var selectedView: CustomView?
    @State private var showingEditView = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Default Views") {
                    ForEach(customViews.filter { $0.isDefault }) { view in
                        NavigationLink(destination: CustomViewTasksView(customView: view)) {
                            CustomViewRow(view: view)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                selectedView = view
                                showingEditView = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(DSColors.accentPrimary)
                        }
                    }
                }
                
                Section("My Views") {
                    ForEach(customViews.filter { !$0.isDefault }) { view in
                        NavigationLink(destination: CustomViewTasksView(customView: view)) {
                            CustomViewRow(view: view)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                selectedView = view
                                showingEditView = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(DSColors.accentPrimary)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deleteView(view)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Custom Views")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAddView = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddView) {
                EditCustomViewView(view: nil)
            }
            .sheet(item: $selectedView) { view in
                EditCustomViewView(view: view)
            }
            .onAppear {
                initializeDefaultViews()
            }
        }
    }
    
    private func deleteView(_ view: CustomView) {
        try? CustomViewService.shared.deleteView(view, context: modelContext)
    }
    
    private func initializeDefaultViews() {
        try? CustomViewService.shared.initializeDefaultViews(context: modelContext)
    }
}

// MARK: - Custom View Row

struct CustomViewRow: View {
    let view: CustomView
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: view.icon)
                .font(DSFonts.headline())
                .foregroundColor(view.color)
                .frame(width: 36, height: 36)
                .background(view.color.opacity(0.1))
                .cornerRadius(UIConstants.CornerRadius.standard)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(view.name)
                    .font(DSFonts.body())
                
                HStack(spacing: 4) {
                    Image(systemName: view.layoutType.icon)
                        .font(DSFonts.caption())
                    Text(view.layoutType.displayName)
                        .font(DSFonts.caption())
                    
                    if let groupBy = view.groupBy, groupBy != .none {
                        Text("•")
                            .font(DSFonts.caption())
                        Text("Grouped by \(groupBy.displayName)")
                            .font(DSFonts.caption())
                    }
                }
                .foregroundColor(DSColors.textSecondary)
            }
            
            Spacer()
            
            if view.isDefault {
                Image(systemName: "star.fill")
                    .font(DSFonts.caption())
                    .foregroundColor(.yellow)
            }
        }
    }
}

#Preview {
    CustomViewsListView()
        .modelContainer(for: [CustomView.self], inMemory: true)
}
