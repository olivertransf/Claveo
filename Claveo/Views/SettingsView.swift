//
//  SettingsView.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @AppStorage("a4ReferenceFrequency") private var a4ReferenceFrequency: Double = 440.0
    @AppStorage("defaultMetronomeTempo") private var defaultMetronomeTempo: Int = 120
    @AppStorage("showFrequencyDisplay") private var showFrequencyDisplay: Bool = true
    @AppStorage("showAdvancedDictionaryItems") private var showAdvancedDictionaryItems: Bool = true
    
    @State private var showingStorageInfo = false
    
    var body: some View {
        NavigationStack {
            List {
                // Tuner Settings
                Section("Tuner") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("A4 Reference Frequency")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Slider(value: $a4ReferenceFrequency, in: 400...480, step: 1)
                            Text("\(Int(a4ReferenceFrequency)) Hz")
                                .font(.body)
                                .monospacedDigit()
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    // Preset frequencies
                    Menu("Preset Frequencies") {
                        Button("Modern Standard (A440)") {
                            a4ReferenceFrequency = 440.0
                        }
                        Button("Baroque (A415)") {
                            a4ReferenceFrequency = 415.0
                        }
                        Button("Classical (A430)") {
                            a4ReferenceFrequency = 430.0
                        }
                        Button("Verdi (A432)") {
                            a4ReferenceFrequency = 432.0
                        }
                        Button("Historical (A409)") {
                            a4ReferenceFrequency = 409.0
                        }
                        Button("Early Music (A392)") {
                            a4ReferenceFrequency = 392.0
                        }
                    }
                    
                    Toggle("Show Frequency Display", isOn: $showFrequencyDisplay)
                }
                
                // Metronome Settings
                Section("Metronome") {
                    Stepper(value: $defaultMetronomeTempo, in: 30...300, step: 1) {
                        HStack {
                            Text("Default Tempo")
                            Spacer()
                            Text("\(defaultMetronomeTempo) BPM")
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
                
                // Dictionary Settings
                Section("Dictionary") {
                    Toggle("Show Advanced Symbols & Terms", isOn: $showAdvancedDictionaryItems)
                        .help("Hide specialized and lesser-known musical symbols and terms")
                }
                
                // Appearance Settings
                Section("Appearance") {
                    Picker("Accent Color", selection: $themeManager.accentColorOption) {
                        ForEach(AccentColorOption.allCases) { option in
                            HStack {
                                Circle()
                                    .fill(option.color)
                                    .frame(width: 20, height: 20)
                                Text(option.rawValue)
                            }
                            .tag(option)
                        }
                    }
                }
                
                // Storage Settings
                Section("Storage") {
                    Button(action: {
                        showingStorageInfo = true
                    }) {
                        HStack {
                            Text("Storage Location")
                            Spacer()
                            Text(iCloudManager.shared.getStorageLocation())
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    if iCloudManager.shared.isAvailable {
                        Label("iCloud Drive Enabled", systemImage: "icloud.fill")
                            .foregroundColor(.themeAccent)
                    } else {
                        Label("Using Local Storage", systemImage: "folder.fill")
                            .foregroundColor(.themeSecondaryLabel)
                    }
                }
                
                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                    
                    Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                    Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingStorageInfo) {
                StorageInfoView()
            }
        }
    }
    
    private var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return "\(version) (\(build))"
        }
        return "1.0"
    }
}

struct StorageInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Your recordings are stored in:")
                    .font(.headline)
                
                Text(iCloudManager.shared.getStoragePath())
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .background(Color.themeTertiaryBackground)
                    .cornerRadius(8)
                
                if iCloudManager.shared.isAvailable {
                    Label("Files will automatically sync to iCloud Drive", systemImage: "icloud.fill")
                        .foregroundColor(.themeAccent)
                } else {
                    Label("iCloud Drive is not available. Files are stored locally.", systemImage: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                }
                
                Text("You can access your recordings in the Files app under:")
                    .font(.subheadline)
                    .foregroundColor(.themeSecondaryLabel)
                
                Text("iCloud Drive → Claveo → Documents")
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .background(Color.themeTertiaryBackground)
                    .cornerRadius(8)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Storage Information")
            .navigationBarTitleDisplayMode(.inline)
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

#Preview {
    SettingsView()
}

