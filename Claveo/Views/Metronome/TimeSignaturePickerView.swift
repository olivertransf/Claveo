//
//  TimeSignaturePickerView.swift
//  Claveo
//
//  Extracted from MetronomeView for easier maintenance.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

struct TimeSignaturePickerView: View {
    @Binding var selectedSignature: TimeSignature
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        NavigationStack {
            List {
                ForEach(TimeSignature.allCases, id: \.self) { signature in
                    Button(action: {
                        selectedSignature = signature
                        dismiss()
                    }) {
                        HStack {
                            Text(signature.rawValue)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedSignature == signature {
                                Image(systemName: "checkmark")
                                    .foregroundColor(themeManager.accentColor)
                            }
                        }
                    }
                }
            }
            .claveoInsetGroupedListStyle()
            .navigationTitle("Time Signature")
            .navigationBarTitleDisplayMode(.inline)
            .tint(themeManager.accentColor)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}


