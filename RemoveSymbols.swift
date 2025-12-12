import Foundation

// Script to remove symbols from dictionary terms

struct MusicTerm: Codable {
    let term: String
    let definition: String
    let category: String
    let example: String?
}

struct MusicDictionary: Codable {
    var terms: [MusicTerm]
}

let fileManager = FileManager.default
let currentDir = fileManager.currentDirectoryPath
let jsonPath = "\(currentDir)/Claveo/Resources/musicDictionary.json"

print("📚 Loading dictionary...")
guard let jsonData = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)) else {
    print("❌ Could not read musicDictionary.json")
    exit(1)
}

// Decode with symbols first, then create new structure without them
struct OldMusicTerm: Codable {
    let term: String
    let definition: String
    let category: String
    let example: String?
    let symbol: String?
    let smuflCode: String?
}

struct OldMusicDictionary: Codable {
    var terms: [OldMusicTerm]
}

guard let oldDictionary = try? JSONDecoder().decode(OldMusicDictionary.self, from: jsonData) else {
    print("❌ Could not decode JSON")
    exit(1)
}

print("✅ Loaded \(oldDictionary.terms.count) terms")
print("🔄 Removing symbols...\n")

// Convert to new structure without symbols
let terms = oldDictionary.terms.map { oldTerm -> MusicTerm in
    MusicTerm(
        term: oldTerm.term,
        definition: oldTerm.definition,
        category: oldTerm.category,
        example: oldTerm.example
    )
}

let dictionary = MusicDictionary(terms: terms)

print("✅ Removed symbols from all terms")

// Write updated dictionary
if let encoded = try? JSONEncoder().encode(dictionary) {
    try? encoded.write(to: URL(fileURLWithPath: jsonPath))
    print("\n✅ Updated dictionary saved to: musicDictionary.json")
} else {
    print("\n❌ Failed to encode dictionary")
    exit(1)
}


