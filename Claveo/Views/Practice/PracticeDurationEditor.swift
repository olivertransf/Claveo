//
//  PracticeDurationEditor.swift
//  Claveo
//
//  Copyright (c) 2026 Oliver Tran

import SwiftUI

struct DurationEntryButton: View {
    @Binding var minutes: Int
    var maximum: Int
    var prominent = false

    @State private var isEditing = false
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 2) {
            if isEditing {
                TextField("0", text: $text)
                    .keyboardType(.numberPad)
                    .focused($focused)
                    .font(prominent ? .system(size: 40, weight: .bold, design: .rounded) : .body.monospacedDigit())
                    .monospacedDigit()
                    .frame(minWidth: prominent ? 88 : 56)
                    .accessibilityLabel(String(localized: "Minutes"))
            } else {
                Button(action: beginEditing) {
                    Text(PracticeDuration.label(minutes: minutes))
                        .font(prominent ? .system(size: 40, weight: .bold, design: .rounded) : .caption.monospacedDigit())
                        .monospacedDigit()
                        .foregroundStyle(prominent ? Color.primary : Color.secondary)
                }
                .accessibilityLabel(String(localized: "Edit Duration"))
            }

            Button(action: beginEditing) {
                Image(systemName: "pencil")
                    .font(prominent ? .body.weight(.semibold) : .caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(String(localized: "Edit Duration"))
        }
        .onChange(of: isEditing) { _, editing in
            guard editing else { return }
            Task { @MainActor in
                focused = true
            }
        }
        .onChange(of: focused) { _, isFocused in
            if !isFocused {
                commit()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if focused {
                    Spacer()
                    Button("Done") {
                        commit()
                        focused = false
                    }
                }
            }
        }
    }

    private func beginEditing() {
        if !isEditing {
            text = String(minutes)
            isEditing = true
        }
        focused = true
    }

    private func commit() {
        guard isEditing else { return }
        let digits = text.filter(\.isNumber)
        if let value = Int(digits) {
            minutes = PracticeDuration.clamp(value, maximum: maximum)
        }
        isEditing = false
    }
}

struct PracticeDurationControls: View {
    let title: String
    @Binding var minutes: Int
    var maximum: Int
    @State private var draft: Double?

    private var shown: Int {
        if let draft {
            return PracticeDuration.clamp(Int(draft), maximum: maximum)
        }
        return minutes
    }

    private var hourLimit: Int {
        max(PracticeDuration.clampMaximum(maximum) / 60, 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                DurationEntryButton(minutes: $minutes, maximum: maximum)
            }

            Slider(
                value: Binding(
                    get: { draft ?? Double(minutes) },
                    set: { draft = $0 }
                ),
                in: Double(PracticeDuration.minimum)...Double(PracticeDuration.clampMaximum(maximum)),
                step: Double(PracticeDuration.step),
                onEditingChanged: { editing in
                    guard !editing else { return }
                    let next = PracticeDuration.clamp(Int(draft ?? Double(minutes)), maximum: maximum)
                    draft = nil
                    minutes = next
                }
            )
            .accessibilityLabel(title)
            .accessibilityValue(PracticeDuration.label(minutes: shown))

            HStack(spacing: 16) {
                Stepper(value: hoursBinding, in: 0...hourLimit) {
                    Text(String(localized: "\(shown / 60) hr"))
                        .font(.subheadline.monospacedDigit())
                }
                .accessibilityLabel(String(localized: "Hours"))

                Stepper(value: minutePartBinding, in: 0...55, step: 5) {
                    Text(String(localized: "\(shown % 60) min"))
                        .font(.subheadline.monospacedDigit())
                }
                .accessibilityLabel(String(localized: "Minutes"))
            }
        }
    }

    private var hoursBinding: Binding<Int> {
        Binding(
            get: { shown / 60 },
            set: { newHours in
                draft = nil
                let next = newHours * 60 + (minutes % 60)
                minutes = PracticeDuration.clamp(next, maximum: maximum)
            }
        )
    }

    private var minutePartBinding: Binding<Int> {
        Binding(
            get: { (shown % 60 / PracticeDuration.step) * PracticeDuration.step },
            set: { newMinutes in
                draft = nil
                let next = (minutes / 60) * 60 + newMinutes
                minutes = PracticeDuration.clamp(next, maximum: maximum)
            }
        )
    }
}

struct QuickDurationOptionsEditor: View {
    @Binding var options: [Int]
    var maximum: Int
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var editingIndex: Int?
    @State private var editingMinutes = PracticeDuration.minimum

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Duration Options")
                .font(.subheadline)
            Text("Tap a time to change it.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                        chip(index: index, minutes: option)
                    }
                    if options.count < PracticeDuration.maximumQuickOptions {
                        Button {
                            addOption()
                        } label: {
                            Image(systemName: "plus")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(themeManager.accentColor)
                                .frame(minWidth: 44, minHeight: 44)
                                .background(themeManager.accentWash)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .accessibilityLabel(String(localized: "Add duration option"))
                    }
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { editingIndex != nil },
            set: { if !$0 { editingIndex = nil } }
        )) {
            NavigationStack {
                Form {
                    PracticeDurationControls(
                        title: String(localized: "Duration"),
                        minutes: $editingMinutes,
                        maximum: maximum
                    )
                }
                .navigationTitle("Edit Duration")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { editingIndex = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { commitEdit() }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private func chip(index: Int, minutes: Int) -> some View {
        HStack(spacing: 4) {
            Button {
                editingIndex = index
                editingMinutes = minutes
            } label: {
                Text(PracticeDuration.label(minutes: minutes))
                    .font(.subheadline.weight(.medium).monospacedDigit())
                    .foregroundStyle(themeManager.accentColor)
                    .frame(minHeight: 44)
            }
            .accessibilityLabel(String(localized: "Edit \(PracticeDuration.label(minutes: minutes))"))

            Button {
                options.remove(at: index)
                if options.isEmpty {
                    options = PracticeDuration.sanitizedOptions([], maximum: maximum)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(String(localized: "Remove \(PracticeDuration.label(minutes: minutes))"))
        }
        .padding(.leading, 10)
        .background(themeManager.accentWash)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func addOption() {
        let candidates = [15, 30, 45, 60, 90, 120, 180, 240, 360]
        let next = candidates
            .map { PracticeDuration.clamp($0, maximum: maximum) }
            .first { !options.contains($0) }
            ?? PracticeDuration.clamp(maximum, maximum: maximum)
        options.append(next)
        options = PracticeDuration.sanitizedOptions(options, maximum: maximum)
    }

    private func commitEdit() {
        guard let editingIndex, options.indices.contains(editingIndex) else {
            self.editingIndex = nil
            return
        }
        options[editingIndex] = PracticeDuration.clamp(editingMinutes, maximum: maximum)
        options = PracticeDuration.sanitizedOptions(options, maximum: maximum)
        self.editingIndex = nil
    }
}
