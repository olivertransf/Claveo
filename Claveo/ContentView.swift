//
//  ContentView.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject private var settingsManager: SettingsManager
    @StateObject private var toneGenerator = ToneGeneratorEngine()
    @State private var selectedTabIndex: Int = {
        let tab = SettingsManager.shared.settings.lastSelectedTab
        return (0...7).contains(tab) ? tab : 0
    }()
    /// Compact tab bar selection. `moreTabValue` is the More hub; bar tabs use semantic ids.
    @State private var compactTabSelection: Int = {
        let tab = SettingsManager.shared.settings.lastSelectedTab
        let valid = (0...7).contains(tab) ? tab : 0
        let bar = Array(
            AppSettings.normalizedTabBarOrder(SettingsManager.shared.settings.tabBarCustomizationOrder).prefix(4)
        )
        return bar.contains(valid) ? valid : ContentView.moreTabValue
    }()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private static let moreTabValue = 8

    private var tabOrder: [Int] {
        AppSettings.normalizedTabBarOrder(settingsManager.settings.tabBarCustomizationOrder)
    }

    private var barSemanticIds: [Int] {
        Array(tabOrder.prefix(4))
    }

    private var moreSemanticIds: [Int] {
        Array(tabOrder.dropFirst(4))
    }

    /// Semantic tab whose root is actually on screen. Nil while the More hub is at its root.
    private var visibleSemanticId: Int? {
        if horizontalSizeClass == .compact {
            if compactTabSelection == Self.moreTabValue {
                return moreSemanticIds.contains(selectedTabIndex) ? selectedTabIndex : nil
            }
            return compactTabSelection
        }
        return selectedTabIndex
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                compactTabView
            } else {
                regularTabView
            }
        }
        .tint(themeManager.accentColor)
        .environmentObject(toneGenerator)
        .onChange(of: selectedTabIndex) { _, newIndex in
            handleTabChange(newIndex: newIndex)
        }
        .onChange(of: compactTabSelection) { _, newValue in
            guard newValue != Self.moreTabValue else { return }
            guard barSemanticIds.contains(newValue) else { return }
            if selectedTabIndex != newValue {
                selectedTabIndex = newValue
            }
        }
        .onChange(of: horizontalSizeClass) { _, _ in
            syncCompactSelection()
        }
        .onChange(of: settingsManager.settings.tabBarCustomizationOrder) { _, _ in
            syncCompactSelection()
        }
    }

    private var compactTabView: some View {
        TabView(selection: $compactTabSelection) {
            ForEach(barSemanticIds, id: \.self) { semanticId in
                Tab(
                    AppTabRegistry.title(semanticId),
                    systemImage: AppTabRegistry.systemImage(semanticId),
                    value: semanticId
                ) {
                    DeferredTab(isActive: visibleSemanticId == semanticId) {
                        FeatureRootView(
                            semanticId: semanticId,
                            isTabSelected: visibleSemanticId == semanticId
                        )
                    }
                }
            }

            Tab("More", systemImage: "ellipsis", value: Self.moreTabValue) {
                MoreHubView(
                    tabs: moreSemanticIds,
                    selectedTabIndex: $selectedTabIndex,
                    isMoreSelected: compactTabSelection == Self.moreTabValue
                )
            }
        }
    }

    private var regularTabView: some View {
        TabView(selection: $selectedTabIndex) {
            ForEach(tabOrder, id: \.self) { semanticId in
                Tab(
                    AppTabRegistry.title(semanticId),
                    systemImage: AppTabRegistry.systemImage(semanticId),
                    value: semanticId
                ) {
                    DeferredTab(isActive: visibleSemanticId == semanticId) {
                        FeatureRootView(
                            semanticId: semanticId,
                            isTabSelected: visibleSemanticId == semanticId
                        )
                    }
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }

    private func syncCompactSelection() {
        if barSemanticIds.contains(selectedTabIndex) {
            compactTabSelection = selectedTabIndex
        } else {
            compactTabSelection = Self.moreTabValue
        }
    }

    private func handleTabChange(newIndex: Int) {
        HapticFeedback.selection()
        if newIndex != 1, settingsManager.settings.stopToneWhenLeavingMetronomeTab {
            toneGenerator.stop()
        }
        UserDefaults.standard.set(newIndex, forKey: "lastSelectedTab")
        NotificationCenter.default.post(
            name: .claveoSelectedTabChanged,
            object: nil,
            userInfo: ["index": newIndex]
        )
    }
}

struct FeatureRootView: View {
    let semanticId: Int
    let isTabSelected: Bool

    var body: some View {
        switch semanticId {
        case 0:
            RecordingListView()
        case 1:
            MetronomeView()
        case 2:
            TunerView(isTabSelected: isTabSelected)
        case 3:
            PracticeView()
        case 4:
            ExercisesRootView()
        case 5:
            MusicDictionaryView(isTabSelected: isTabSelected)
        case 6:
            SettingsView()
        case 7:
            ChordScaleReferenceView()
        default:
            EmptyView()
        }
    }
}

private struct DeferredTab<Content: View>: View {
    let isActive: Bool
    @ViewBuilder var content: () -> Content
    @State private var hasLoaded = false

    var body: some View {
        Group {
            if hasLoaded {
                content()
            } else {
                Color.clear
            }
        }
        .onChange(of: isActive, initial: true) { _, active in
            if active {
                hasLoaded = true
            }
        }
    }
}

private struct MoreHubView: View {
    let tabs: [Int]
    @Binding var selectedTabIndex: Int
    let isMoreSelected: Bool
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var path = NavigationPath()
    @State private var didRestore = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    ForEach(tabs, id: \.self) { semanticId in
                        NavigationLink(value: semanticId) {
                            MoreHubCard(
                                title: AppTabRegistry.title(semanticId),
                                systemImage: AppTabRegistry.systemImage(semanticId),
                                tint: themeManager.accentColor
                            )
                        }
                        .buttonStyle(ClaveoPressButtonStyle())
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("More")
            .navigationDestination(for: Int.self) { semanticId in
                FeatureRootView(
                    semanticId: semanticId,
                    isTabSelected: isMoreSelected && selectedTabIndex == semanticId
                )
                .onAppear {
                    if selectedTabIndex != semanticId {
                        selectedTabIndex = semanticId
                    }
                }
            }
        }
        .onAppear(perform: restoreIfNeeded)
        .onChange(of: selectedTabIndex) { _, newValue in
            if !tabs.contains(newValue), !path.isEmpty {
                path = NavigationPath()
            }
        }
        .onChange(of: tabs) { _, newTabs in
            if !path.isEmpty, !newTabs.contains(selectedTabIndex) {
                path = NavigationPath()
            }
        }
    }

    private func restoreIfNeeded() {
        guard !didRestore else { return }
        didRestore = true
        if tabs.contains(selectedTabIndex), path.isEmpty {
            path.append(selectedTabIndex)
        }
    }
}

private struct MoreHubCard: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.14), in: Circle())
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .claveoCard()
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(title)
    }
}

#Preview {
    ContentView()
        .environmentObject(ThemeManager.shared)
        .environmentObject(SettingsManager.shared)
}
