//
//  iCloudManager.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//
//  Copyright (c) 2025 Oliver Tran

import Foundation

/// Manages iCloud Drive sync for recordings and metadata
/// Follows Apple's best practices for iCloud document synchronization
/// Automatically falls back to local storage if iCloud is unavailable
class iCloudManager {
    static let shared = iCloudManager()
    
    private let containerIdentifier = "iCloud.com.olivertran.Claveo"
    private let fileCoordinator = NSFileCoordinator()
    
    private init() {}
    
    /// Returns the iCloud Documents URL if iCloud is available and signed in
    /// Uses file coordination to ensure thread-safe access
    var documentsURL: URL? {
        guard let ubiquityURL = FileManager.default.url(forUbiquityContainerIdentifier: containerIdentifier) else {
            return nil
        }
        let documentsURL = ubiquityURL.appendingPathComponent("Documents")
        
        // Use file coordinator to safely create directory
        var error: NSError?
        fileCoordinator.coordinate(writingItemAt: documentsURL, options: [], error: &error) { writingURL in
            if !FileManager.default.fileExists(atPath: writingURL.path) {
                try? FileManager.default.createDirectory(at: writingURL, withIntermediateDirectories: true)
            }
        }
        
        if error != nil {
            return nil
        }
        
        return documentsURL
    }
    
    /// Checks if iCloud Drive is available and the user is signed in
    var isAvailable: Bool {
        return documentsURL != nil
    }
    
    /// Returns the documents URL (iCloud if available, otherwise local)
    /// Files saved to this URL will automatically sync to iCloud if available
    func getDocumentsURL() -> URL {
        // Return iCloud URL if available, otherwise fall back to local Documents
        if let iCloudURL = documentsURL {
            return iCloudURL
        }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    /// Safely writes data to a file using file coordination
    /// This ensures proper iCloud sync and thread safety
    func writeFile(data: Data, to url: URL) throws {
        var coordinationError: NSError?
        var writeError: Error?
        
        fileCoordinator.coordinate(writingItemAt: url, options: [], error: &coordinationError) { writingURL in
            do {
                try data.write(to: writingURL, options: [.atomic])
            } catch {
                writeError = error
            }
        }
        
        if let coordinationError = coordinationError {
            throw coordinationError
        }
        if let writeError = writeError {
            throw writeError
        }
    }
    
    /// Safely reads data from a file using file coordination
    func readFile(from url: URL) throws -> Data {
        var coordinationError: NSError?
        var readError: Error?
        var fileData: Data?
        
        fileCoordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { readingURL in
            do {
                fileData = try Data(contentsOf: readingURL)
            } catch {
                readError = error
            }
        }
        
        if let coordinationError = coordinationError {
            throw coordinationError
        }
        if let readError = readError {
            throw readError
        }
        
        guard let data = fileData else {
            throw NSError(domain: "iCloudManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to read file"])
        }
        
        return data
    }
    
    /// Returns the current storage location description for debugging
    func getStorageLocation() -> String {
        if isAvailable {
            return "iCloud Drive"
        }
        return "Local Storage"
    }
    
    /// Returns the full path where files are being saved (for debugging)
    func getStoragePath() -> String {
        return getDocumentsURL().path
    }
}

