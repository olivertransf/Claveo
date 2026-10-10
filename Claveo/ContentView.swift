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
    @State private var moreTab = MoreTabController()

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
                guard let route = moreTab.route, moreSemanticIds.contains(route) else { return nil }
                return route
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
        .environment(moreTab)
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
            if let route = moreTab.route, !moreSemanticIds.contains(route) {
                moreTab.route = nil
            }
        }
    }

    /// iPad always shows names. iPhone follows the Settings toggle.
    private var showTabBarText: Bool {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return true
        }
        return settingsManager.settings.showTabBarText
    }

    @ViewBuilder
    private func tabLabel(title: String, systemImage: String) -> some View {
        if showTabBarText {
            Label(title, systemImage: systemImage)
        } else {
            Image(systemName: systemImage)
                .accessibilityLabel(title)
        }
    }

    private var compactTabView: some View {
        TabView(selection: $compactTabSelection) {
            ForEach(barSemanticIds, id: \.self) { semanticId in
                Tab(value: semanticId) {
                    DeferredTab(isActive: visibleSemanticId == semanticId) {
                        FeatureRootView(
                            semanticId: semanticId,
                            isTabSelected: visibleSemanticId == semanticId
                        )
                    }
                } label: {
                    tabLabel(
                        title: AppTabRegistry.title(semanticId),
                        systemImage: AppTabRegistry.systemImage(semanticId)
                    )
                }
            }

            Tab(value: Self.moreTabValue) {
                MoreHubView(
                    tabs: moreSemanticIds,
                    selectedTabIndex: $selectedTabIndex,
                    isMoreSelected: compactTabSelection == Self.moreTabValue
                )
            } label: {
                tabLabel(title: String(localized: "More"), systemImage: "ellipsis")
            }
        }
    }

    private var regularTabView: some View {
        TabView(selection: $selectedTabIndex) {
            ForEach(tabOrder, id: \.self) { semanticId in
                Tab(value: semanticId) {
                    DeferredTab(isActive: visibleSemanticId == semanticId) {
                        FeatureRootView(
                            semanticId: semanticId,
                            isTabSelected: visibleSemanticId == semanticId
                        )
                    }
                } label: {
                    tabLabel(
                        title: AppTabRegistry.title(semanticId),
                        systemImage: AppTabRegistry.systemImage(semanticId)
                    )
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

@Observable
final class MoreTabController {
    var route: Int?
}

private struct MoreHubView: View {
    let tabs: [Int]
    @Binding var selectedTabIndex: Int
    let isMoreSelected: Bool
    @Environment(MoreTabController.self) private var moreTab
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        if let route = moreTab.route, tabs.contains(route) {
            FeatureRootView(
                semanticId: route,
                isTabSelected: isMoreSelected
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("More")
                        .font(.largeTitle.bold())
                    VStack(spacing: 12) {
                        ForEach(Array(stride(from: 0, to: tabs.count, by: 2)), id: \.self) { start in
                            HStack(spacing: 12) {
                                moreLink(tabs[start])
                                if start + 1 < tabs.count {
                                    moreLink(tabs[start + 1])
                                } else {
                                    Color.clear
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
        }
    }

    private func moreLink(_ semanticId: Int) -> some View {
        Button {
            selectedTabIndex = semanticId
            moreTab.route = semanticId
        } label: {
            MoreHubCard(
                title: AppTabRegistry.title(semanticId),
                systemImage: AppTabRegistry.systemImage(semanticId),
                tint: themeManager.accentColor
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
    }
}

private struct MoreTabBackButtonModifier: ViewModifier {
    @Environment(MoreTabController.self) private var moreTab: MoreTabController?
    @Environment(\.dismiss) private var dismiss
    let semanticId: Int

    func body(content: Content) -> some View {
        content.toolbar {
            if moreTab?.route == semanticId {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        moreTab?.route = nil
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.backward")
                                .font(.body.weight(.semibold))
                            Text("More")
                        }
                    }
                    .accessibilityLabel("More")
                }
            }
        }
    }
}

extension View {
    func moreTabBackButton(for semanticId: Int) -> some View {
        modifier(MoreTabBackButtonModifier(semanticId: semanticId))
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
    }
}

#Preview {
    ContentView()
        .environmentObject(ThemeManager.shared)
        .environmentObject(SettingsManager.shared)
}
