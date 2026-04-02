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
    /// Drives the tab bar's visual highlight on compact screens (0–3, or 99 for the More slot).
    @State private var tabBarHighlight: Int = {
        let tab = SettingsManager.shared.settings.lastSelectedTab
        return tab >= 4 ? 99 : tab
    }()
    @State private var showMoreMenu = false
    @State private var moreTabHandler = MoreTabHandler()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let overflowTabs: [(tag: Int, name: String, icon: String)] = [
        (4, "Exercises", "list.bullet.clipboard"),
        (5, "Dictionary", "book"),
        (7, "Chords", "music.note.list"),
        (6, "Settings", "gear")
    ]

    var showTabBarText: Bool {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return true
        }
        return settingsManager.settings.showTabBarText
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
                        withAnimation(.spring(duration: 0.25)) {
                            showMoreMenu = false
                        }
                    }

                MoreMenuView(
                    tabs: overflowTabs,
                    selectedTabIndex: $selectedTabIndex,
                    tabBarHighlight: $tabBarHighlight,
                    showMoreMenu: $showMoreMenu
                )
                .environmentObject(themeManager)
                .padding(.bottom, 66)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.25), value: showMoreMenu)
        .onChange(of: showMoreMenu) { _, isShowing in
            // Snap highlight back when menu is dismissed without picking an overflow tab.
            if !isShowing && selectedTabIndex < 4 {
                tabBarHighlight = selectedTabIndex
            }
        }
        .onChange(of: horizontalSizeClass) { _, _ in
            tabBarHighlight = selectedTabIndex < 4 ? selectedTabIndex : 99
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
                    if selectedTabIndex >= 4 { tabBarHighlight = 99 }
                    withAnimation(.spring(duration: 0.25)) {
                        showMoreMenu = true
                    }
                } else {
                    tabBarHighlight = newValue
                    selectedTabIndex = newValue
                    withAnimation(.spring(duration: 0.25)) {
                        showMoreMenu = false
                    }
                }
            }
        )
    }

    private var compactTabView: some View {
        TabView(selection: tabViewSelection) {
            RecordingListView()
                .tabItem {
                    if showTabBarText {
                        Label("Recordings", systemImage: "waveform")
                    } else {
                        Image(systemName: "waveform")
                    }
                }
                .tag(0)

            MetronomeView()
                .environmentObject(toneGenerator)
                .tabItem {
                    if showTabBarText {
                        Label("Metronome", systemImage: "metronome")
                    } else {
                        Image(systemName: "metronome")
                    }
                }
                .tag(1)

            TunerView()
                .tabItem {
                    if showTabBarText {
                        Label("Tuner", systemImage: "tuningfork")
                    } else {
                        Image(systemName: "tuningfork")
                    }
                }
                .tag(2)

            PracticeView()
                .tabItem {
                    if showTabBarText {
                        Label("Practice", systemImage: "calendar.badge.clock")
                    } else {
                        Image(systemName: "calendar.badge.clock")
                    }
                }
                .tag(3)

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
                // Keep the current regular tab visible as background; only
                // switch to the overflow slot when already on an overflow tab.
                if selectedTabIndex >= 4 {
                    tabBarHighlight = 99
                }
                withAnimation(.spring(duration: 0.25)) {
                    showMoreMenu = true
                }
            }
        )
    }

    /// Both overflow views stay in the hierarchy so their @State survives tab switches.
    @ViewBuilder
    private var overflowContent: some View {
        ZStack {
            ExercisesRootView()
                .opacity(selectedTabIndex == 4 ? 1 : 0)
                .allowsHitTesting(selectedTabIndex == 4)
            MusicDictionaryView()
                .opacity(selectedTabIndex == 5 ? 1 : 0)
                .allowsHitTesting(selectedTabIndex == 5)
            SettingsView()
                .opacity(selectedTabIndex == 6 ? 1 : 0)
                .allowsHitTesting(selectedTabIndex == 6)
            ChordScaleReferenceView()
                .opacity(selectedTabIndex == 7 ? 1 : 0)
                .allowsHitTesting(selectedTabIndex == 7)
        }
    }

    // MARK: - Full layout (iPad)

    private var fullTabView: some View {
        TabView(selection: $selectedTabIndex) {
            RecordingListView()
                .tabItem { Label("Recordings", systemImage: "waveform") }
                .tag(0)
            MetronomeView()
                .environmentObject(toneGenerator)
                .tabItem { Label("Metronome", systemImage: "metronome") }
                .tag(1)
            TunerView()
                .tabItem { Label("Tuner", systemImage: "tuningfork") }
                .tag(2)
            PracticeView()
                .tabItem { Label("Practice", systemImage: "calendar.badge.clock") }
                .tag(3)
            ExercisesRootView()
                .tabItem { Label("Exercises", systemImage: "list.bullet.clipboard") }
                .tag(4)
            MusicDictionaryView()
                .tabItem { Label("Dictionary", systemImage: "book") }
                .tag(5)
            ChordScaleReferenceView()
                .tabItem { Label("Chords", systemImage: "music.note.list") }
                .tag(7)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(6)
        }
        .tint(themeManager.accentColor)
        .onChange(of: selectedTabIndex) { _, newIndex in
            handleTabChange(newIndex: newIndex)
        }
    }

    // MARK: - Helpers

    private func handleTabChange(newIndex: Int) {
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
                    withAnimation(.spring(duration: 0.25)) {
                        showMoreMenu = false
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20))
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
                .buttonStyle(.plain)
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
