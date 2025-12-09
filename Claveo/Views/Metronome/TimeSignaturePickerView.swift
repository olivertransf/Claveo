//
//  TimeSignaturePickerView.swift
//  Claveo
//
//  Extracted from MetronomeView for easier maintenance.
//

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
            .navigationTitle("Time Signature")
            .navigationBarTitleDisplayMode(.inline)
            .tint(themeManager.accentColor)
            .accentColor(themeManager.accentColor)
            .id(themeManager.accentColorOption)
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


