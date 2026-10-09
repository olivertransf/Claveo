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
    var lastModified: Date
    var isDeleted: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        composer: String? = nil,
        createdAt: Date = Date(),
        lastModified: Date? = nil,
        isDeleted: Bool = false
    ) {
        self.id = id
        self.name = name
        self.composer = composer
        self.createdAt = createdAt
        self.lastModified = lastModified ?? createdAt
        self.isDeleted = isDeleted
    }
    
    var displayName: String {
        if let composer = composer, !composer.isEmpty {
            return "\(name) - \(composer)"
        }
        return name
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case composer
        case createdAt
        case lastModified
        case isDeleted
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        composer = try container.decodeIfPresent(String.self, forKey: .composer)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastModified = try container.decodeIfPresent(Date.self, forKey: .lastModified) ?? createdAt
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
    }
}

