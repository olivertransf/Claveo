//
//  TabBarOrderSettingsView.swift
//  Claveo
//
//  Reorder main app tabs (compact: first four = bar, rest = More).
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

struct TabBarOrderSettingsView: View {
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var order: [Int] = AppSettings.normalizedTabBarOrder(
        SettingsManager.shared.settings.tabBarCustomizationOrder
    )

    var body: some View {
        Form {
            Section {
                ForEach(order, id: \.self) { tabId in
                    tabOrderRow(tabId: tabId)
                }
                .onMove { source, destination in
                    order.move(fromOffsets: source, toOffset: destination)
                }
            } footer: {
                Text(footerExplanation)
            }

            Section {
                Button("Reset to default order") {
                    settingsManager.update(
                        \.tabBarCustomizationOrder,
                        value: AppSettings.defaultTabBarCustomizationOrder
                    )
                }
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Tabs")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            order = AppSettings.normalizedTabBarOrder(settingsManager.settings.tabBarCustomizationOrder)
        }
        .onChange(of: settingsManager.settings.tabBarCustomizationOrder) { _, newValue in
            let next = AppSettings.normalizedTabBarOrder(newValue)
            if next != order {
                order = next
            }
        }
        .onChange(of: order) { _, newValue in
            let next = AppSettings.normalizedTabBarOrder(newValue)
            let current = AppSettings.normalizedTabBarOrder(settingsManager.settings.tabBarCustomizationOrder)
            if next != current {
                settingsManager.update(\.tabBarCustomizationOrder, value: next)
            }
        }
    }

    private var footerExplanation: String {
        let layout: String
        if UIDevice.current.userInterfaceIdiom == .pad {
            layout = "This order is used for every tab in the tab bar."
        } else {
            layout = "The first four tabs sit on the bottom bar; the rest are in More."
        }
        return "Drag a row using the handle on the right to reorder. \(layout)"
    }

    private func placementLabel(for tabId: Int) -> String {
        guard let index = order.firstIndex(of: tabId) else { return "" }
        if index < 4 {
            return "Bottom bar"
        }
        return "More menu"
    }

    @ViewBuilder
    private func tabOrderRow(tabId: Int) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(AppTabRegistry.title(tabId))
                Text(placementLabel(for: tabId))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: AppTabRegistry.systemImage(tabId))
        }
    }
}

#Preview {
    NavigationStack {
        TabBarOrderSettingsView()
    }
}
