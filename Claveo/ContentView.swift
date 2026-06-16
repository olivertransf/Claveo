//
//  ContentView.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var toneGenerator = ToneGeneratorEngine()
    @State private var selectedTabIndex: Int = {
        let tab = SettingsManager.shared.settings.lastSelectedTab
        return (0...7).contains(tab) ? tab : 0
    }()
    /// Drives the tab bar's visual highlight on compact screens (0–3 bar slots, or 99 for the More slot).
    @State private var tabBarHighlight: Int = {
        let tab = SettingsManager.shared.settings.lastSelectedTab
        guard (0...7).contains(tab) else { return 0 }
        let bar = Array(
            AppSettings.normalizedTabBarOrder(SettingsManager.shared.settings.tabBarCustomizationOrder).prefix(4)
        )
        if let idx = bar.firstIndex(of: tab) { return idx }
        return 99
    }()
    @State private var showMoreMenu = false
    @State private var moreTabHandler = MoreTabHandler()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var tabOrder: [Int] {
        AppSettings.normalizedTabBarOrder(settingsManager.settings.tabBarCustomizationOrder)
    }

    private var barSemanticIds: [Int] {
        Array(tabOrder.prefix(4))
    }

    private var moreMenuTabs: [(tag: Int, name: String, icon: String)] {
        tabOrder.dropFirst(4).map {
            (tag: $0, name: AppTabRegistry.title($0), icon: AppTabRegistry.systemImage($0))
        }
    }

    var showTabBarText: Bool {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return true
        }
        return settingsManager.settings.showTabBarText
    }

    @ViewBuilder
    private func tabContent(semanticId: Int) -> some View {
        let isSelected = selectedTabIndex == semanticId
        switch semanticId {
        case 0:
            RecordingListView()
        case 1:
            MetronomeView()
                .environmentObject(toneGenerator)
                .environmentObject(themeManager)
        case 2:
            TunerView()
        case 3:
            PracticeView()
        case 4:
            ExercisesRootView()
        case 5:
            MusicDictionaryView(isTabSelected: isSelected)
        case 6:
            SettingsView()
        case 7:
            ChordScaleReferenceView()
        default:
            EmptyView()
        }
    }

    private func reconcileTabBarHighlight() {
        if let idx = barSemanticIds.firstIndex(of: selectedTabIndex) {
            tabBarHighlight = idx
        } else {
            tabBarHighlight = 99
        }
    }

    // MARK: - Body

    var body: some View {
        if horizontalSizeClass == .compact {
            compactBody
        } else {
            fullTabView
        }
    }

    // MARK: - Compact layout (iPhone / iPad split view)

    @ViewBuilder
    private var compactBody: some View {
        ZStack(alignment: .bottom) {
            compactTabView

            if showMoreMenu {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showMoreMenu = false
                    }

                MoreMenuView(
                    tabs: moreMenuTabs,
                    selectedTabIndex: $selectedTabIndex,
                    tabBarHighlight: $tabBarHighlight,
                    showMoreMenu: $showMoreMenu
                )
                .environmentObject(themeManager)
                .padding(.bottom, 66)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: showMoreMenu)
        .onChange(of: showMoreMenu) { _, isShowing in
            if !isShowing, barSemanticIds.contains(selectedTabIndex) {
                tabBarHighlight = barSemanticIds.firstIndex(of: selectedTabIndex) ?? 0
            }
        }
        .onChange(of: horizontalSizeClass) { _, _ in
            reconcileTabBarHighlight()
        }
        .onChange(of: settingsManager.settings.tabBarCustomizationOrder) { _, _ in
            reconcileTabBarHighlight()
        }
        .onChange(of: selectedTabIndex) { _, newIndex in
            handleTabChange(newIndex: newIndex)
        }
    }

    /// Binding used by the compact TabView.
    ///
    /// `shouldSelect` (in MoreTabHandler) returns `false` for the More item (UIKit index 4),
    /// so this setter is never called for More taps — it only handles regular tabs 0–3.
    /// The `if newValue == 99` branch is a safety net in case the UIKit delegate
    /// hasn't installed yet (e.g. first frame), preventing a black screen.
    private var tabViewSelection: Binding<Int> {
        Binding(
            get: { tabBarHighlight },
            set: { newValue in
                if newValue == 99 {
                    if !barSemanticIds.contains(selectedTabIndex) { tabBarHighlight = 99 }
                    showMoreMenu = true
                } else {
                    guard newValue >= 0, newValue < barSemanticIds.count else { return }
                    tabBarHighlight = newValue
                    selectedTabIndex = barSemanticIds[newValue]
                    withAnimation(.easeOut(duration: 0.2)) {
                        showMoreMenu = false
                    }
                }
            }
        )
    }

    private var compactTabView: some View {
        TabView(selection: tabViewSelection) {
            ForEach(0..<4, id: \.self) { slot in
                let semanticId = barSemanticIds[slot]
                tabContent(semanticId: semanticId)
                    .id(semanticId)
                    .tabItem {
                        if showTabBarText {
                            Label(
                                AppTabRegistry.title(semanticId),
                                systemImage: AppTabRegistry.systemImage(semanticId)
                            )
                        } else {
                            Image(systemName: AppTabRegistry.systemImage(semanticId))
                        }
                    }
                    .tag(slot)
            }

            // Fifth slot: hosts overflow content and serves as the More tap target.
            overflowContent
                .tabItem {
                    if showTabBarText {
                        Label("More", systemImage: "ellipsis")
                    } else {
                        Image(systemName: "ellipsis")
                    }
                }
                .tag(99)
        }
        .tint(themeManager.accentColor)
        // Install the handler that intercepts every More tap (including re-taps
        // on the already-selected item, which SwiftUI's binding alone cannot catch).
        .background(
            MoreTabHandlerInstaller(handler: moreTabHandler) {
                if !barSemanticIds.contains(selectedTabIndex) {
                    tabBarHighlight = 99
                }
                withAnimation(.easeOut(duration: 0.2)) {
                    showMoreMenu = true
                }
            }
        )
    }

    /// Hosts every tab that can appear in the "More" strip (positions 5–8 in `tabOrder`).
    /// Must mirror `moreMenuTabs` semantics — not a fixed 4/5/6/7 list — so reordering can put Recordings, Practice, etc. in overflow.
    @ViewBuilder
    private var overflowContent: some View {
        let overflowSemanticIds = Array(tabOrder.dropFirst(4))
        ZStack {
            ForEach(overflowSemanticIds, id: \.self) { semanticId in
                tabContent(semanticId: semanticId)
                    .id(semanticId)
                    .opacity(selectedTabIndex == semanticId ? 1 : 0)
                    .allowsHitTesting(selectedTabIndex == semanticId)
            }
        }
    }

    // MARK: - Full layout (iPad)

    private var fullTabView: some View {
        TabView(selection: $selectedTabIndex) {
            ForEach(tabOrder, id: \.self) { semanticId in
                tabContent(semanticId: semanticId)
                    .id(semanticId)
                    .tabItem {
                        Label(
                            AppTabRegistry.title(semanticId),
                            systemImage: AppTabRegistry.systemImage(semanticId)
                        )
                    }
                    .tag(semanticId)
            }
        }
        .tint(themeManager.accentColor)
        .onChange(of: selectedTabIndex) { _, newIndex in
            handleTabChange(newIndex: newIndex)
        }
    }

    // MARK: - Helpers

    private func handleTabChange(newIndex: Int) {
        HapticFeedback.selection()
        if newIndex != 1, settingsManager.settings.stopToneWhenLeavingMetronomeTab {
            toneGenerator.stop()
        }
        // Write directly to UserDefaults — avoids mutating @Published settings and triggering
        // re-renders across all 9 SettingsManager observers mid-tab-transition.
        UserDefaults.standard.set(newIndex, forKey: "lastSelectedTab")
        NotificationCenter.default.post(
            name: .claveoSelectedTabChanged,
            object: nil,
            userInfo: ["index": newIndex]
        )
    }

    private var tabBarHeight: CGFloat {
        let safeBottom = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom ?? 0
        return 49 + safeBottom
    }
}

// MARK: - UIKit More-tab interception

/// Handles all taps on the More tab item (UIKit index 4), including re-taps on
/// the already-selected item that SwiftUI's binding setter cannot detect.
///
/// Strategy:
/// - A `UITapGestureRecognizer` on `UITabBar` fires for *every* tap.
///   When the computed index == 4, `onMoreTapped` is called.
/// - `shouldSelect` returning `false` for index 4 prevents UIKit from changing
///   the selection, so SwiftUI's binding setter is NOT also called for the same tap.
private final class MoreTabHandler: NSObject, UITabBarControllerDelegate {
    var onMoreTapped: (() -> Void)?

    private weak var installedTabBarController: UITabBarController?
    private var tapRecognizer: UITapGestureRecognizer?

    func install(on tbc: UITabBarController) {
        guard tbc !== installedTabBarController else { return }
        installedTabBarController = tbc
        tbc.delegate = self

        let gr = UITapGestureRecognizer(target: self, action: #selector(tabBarTapped(_:)))
        gr.cancelsTouchesInView = false
        tbc.tabBar.addGestureRecognizer(gr)
        tapRecognizer = gr
    }

    // Prevent UIKit (and therefore SwiftUI's binding) from processing More taps.
    func tabBarController(
        _ tabBarController: UITabBarController,
        shouldSelect viewController: UIViewController
    ) -> Bool {
        guard let index = tabBarController.viewControllers?.firstIndex(of: viewController) else {
            return true
        }
        return index != 4
    }

    @objc private func tabBarTapped(_ gr: UITapGestureRecognizer) {
        guard
            let tabBar = installedTabBarController?.tabBar,
            let itemCount = tabBar.items?.count, itemCount > 0
        else { return }
        let x = gr.location(in: tabBar).x
        let tappedIndex = max(0, min(itemCount - 1, Int(x / (tabBar.bounds.width / CGFloat(itemCount)))))
        if tappedIndex == 4 {
            onMoreTapped?()
        }
    }
}

/// A zero-size `UIViewRepresentable` placed as a background of the compact TabView.
/// On every SwiftUI update it refreshes the `onMoreTapped` closure (so it always
/// closes over the latest state) and installs the handler on the UITabBarController
/// found by walking up the responder chain.
private struct MoreTabHandlerInstaller: UIViewRepresentable {
    let handler: MoreTabHandler
    let onMoreTapped: () -> Void

    func makeUIView(context: Context) -> UIView { UIView() }

    func updateUIView(_ uiView: UIView, context: Context) {
        handler.onMoreTapped = onMoreTapped
        DispatchQueue.main.async {
            var responder: UIResponder? = uiView
            while let r = responder {
                if let tbc = r as? UITabBarController {
                    handler.install(on: tbc)
                    return
                }
                responder = r.next
            }
        }
    }
}

// MARK: - More Menu Overlay

private struct MoreMenuView: View {
    let tabs: [(tag: Int, name: String, icon: String)]
    @Binding var selectedTabIndex: Int
    @Binding var tabBarHighlight: Int
    @Binding var showMoreMenu: Bool
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.tag) { tab in
                Button {
                    selectedTabIndex = tab.tag
                    tabBarHighlight = 99
                    showMoreMenu = false
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.body.weight(.medium))
                            .foregroundStyle(
                                selectedTabIndex == tab.tag
                                    ? themeManager.accentColor
                                    : Color.secondary
                            )
                        Text(tab.name)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(
                                selectedTabIndex == tab.tag
                                    ? themeManager.accentColor
                                    : Color.secondary
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(Capsule(style: .continuous))
        .padding(.horizontal, 16)
    }
}

#Preview {
    ContentView()
        .environmentObject(ThemeManager.shared)
}
