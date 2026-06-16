//
//  ClaveoTextInputStyles.swift
//  Claveo
//
//  Shared text field and editor styling aligned with grouped app surfaces.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

extension TextFieldStyle where Self == ClaveoInsetTextFieldStyle {
    static var claveoInset: ClaveoInsetTextFieldStyle { ClaveoInsetTextFieldStyle() }
}

extension TextFieldStyle where Self == ClaveoCompactTextFieldStyle {
    static var claveoCompact: ClaveoCompactTextFieldStyle { ClaveoCompactTextFieldStyle() }
}

struct ClaveoInsetTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Color(.tertiarySystemFill),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
    }
}

struct ClaveoCompactTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Color(.tertiarySystemFill),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
    }
}

struct ClaveoSearchField: View {
    @Binding var text: String
    var prompt: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            TextField(prompt, text: $text)
                .textFieldStyle(.plain)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Color(.tertiarySystemFill),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }
}

struct ClaveoMultilineTextInput: View {
    @Binding var text: String
    var placeholder: String
    var minHeight: CGFloat = 100

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, -4)
                .frame(minHeight: minHeight)
        }
        .padding(12)
        .background(
            Color(.tertiarySystemFill),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }
}

extension View {
    func claveoFormTextEditor(minHeight: CGFloat = 100) -> some View {
        frame(minHeight: minHeight)
            .scrollContentBackground(.hidden)
            .padding(.vertical, 2)
    }
}
