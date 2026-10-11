//
//  ClaveoListStyles.swift
//  Claveo
//
//  Shared list styling for native grouped separators and surfaces.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

extension View {
    func claveoInsetGroupedListStyle() -> some View {
        listStyle(.insetGrouped)
            .listSectionSeparator(.hidden, edges: .bottom)
    }

    func claveoPlainListStyle() -> some View {
        listStyle(.plain)
    }

    func claveoListRowChrome(hideSeparator: Bool = false, showsBackground: Bool = true) -> some View {
        modifier(ClaveoListRowChromeModifier(hideSeparator: hideSeparator, showsBackground: showsBackground))
    }

    func splitDetailCardChrome() -> some View {
        padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.themeGroupedBackground)
    }
}

private struct ClaveoListRowChromeModifier: ViewModifier {
    let hideSeparator: Bool
    let showsBackground: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if showsBackground {
            content
                .listRowBackground(Color(.secondarySystemGroupedBackground))
                .listRowSeparator(hideSeparator ? .hidden : .automatic, edges: .bottom)
                .listRowSeparatorTint(Color(.separator))
        } else {
            content
                .listRowSeparator(hideSeparator ? .hidden : .automatic, edges: .bottom)
                .listRowSeparatorTint(Color(.separator))
        }
    }
}
