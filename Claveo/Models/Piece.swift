//
//  Piece.swift
//  Claveo
//
//  Created by Oliver Tran on 11/20/25.
//
//  Copyright (c) 2025 Oliver Tran

import Foundation

struct Piece: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var composer: String?
    var createdAt: Date
    
    init(id: UUID = UUID(), name: String, composer: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.composer = composer
        self.createdAt = createdAt
    }
    
    var displayName: String {
        if let composer = composer, !composer.isEmpty {
            return "\(name) - \(composer)"
        }
        return name
    }
}

