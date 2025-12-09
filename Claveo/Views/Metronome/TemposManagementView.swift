//
//  TemposManagementView.swift
//  Claveo
//
//  Extracted from MetronomeView for readability.
//

import SwiftUI

struct TemposManagementView: View {
    @Binding var tempos: [Int]
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @State private var newTempo = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Add Tempo") {
                    HStack {
                        TextField("BPM", text: $newTempo)
                            .keyboardType(.numberPad)

                        Button("Add") {
                            if let tempo = Int(newTempo), tempo >= 20 && tempo <= 300 {
                                if !tempos.contains(tempo) {
                                    tempos.append(tempo)
                                    tempos.sort()
                                    newTempo = ""
                                }
                            }
                        }
                        .disabled(newTempo.isEmpty || Int(newTempo) == nil || Int(newTempo)! < 20 || Int(newTempo)! > 300)
                    }
                }

                Section {
                    if tempos.isEmpty {
                        Text("No tempos")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowInsets(EdgeInsets())
                    } else {
                        ForEach(tempos.sorted(), id: \.self) { tempo in
                            HStack {
                                Text("\(tempo) BPM")
                                    .font(.body)
                                Spacer()
                                Button(action: {
                                    tempos.removeAll { $0 == tempo }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            let sorted = tempos.sorted()
                            for index in indexSet {
                                if index < sorted.count {
                                    tempos.removeAll { $0 == sorted[index] }
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Tempos")
                        Spacer()
                        if !tempos.isEmpty {
                            Text("\(tempos.count)")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Manage Tempos")
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


