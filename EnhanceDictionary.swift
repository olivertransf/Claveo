import Foundation

// Script to enhance all dictionary definitions using Wikipedia API

struct MusicTerm: Codable {
    let term: String
    var definition: String
    let category: String
    let example: String?
}

struct MusicDictionary: Codable {
    var terms: [MusicTerm]
    let symbols: [MusicSymbol]
}

struct MusicSymbol: Codable {
    let symbol: String
    let unicode: String
    let name: String
    let category: String
    let description: String
    let smuflCode: String?
}

func fetchFromWikipedia(term: String, category: String) async -> String? {
    var searchTerms = [term]
    
    if !term.lowercased().contains("music") && !term.lowercased().contains("musical") {
        searchTerms.append("\(term) (music)")
        searchTerms.append("\(term) music")
    }
    
    switch category.lowercased() {
    case "tempo":
        searchTerms.append("\(term) tempo")
    case "dynamics":
        searchTerms.append("\(term) (music)")
    case "articulation":
        searchTerms.append("\(term) (music)")
    default:
        break
    }
    
    for searchTerm in searchTerms {
        guard let encodedTerm = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/\(encodedTerm)") else {
            continue
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                continue
            }
            
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            if let extract = json?["extract"] as? String {
                var cleaned = extract.replacingOccurrences(of: "\\[\\d+\\]", with: "", options: .regularExpression)
                cleaned = cleaned.replacingOccurrences(of: "\\([^)]*\\)", with: "", options: .regularExpression)
                
                let sentences = cleaned.components(separatedBy: ".")
                var result = ""
                var sentenceCount = 0
                
                for sentence in sentences {
                    let trimmed = sentence.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty { continue }
                    
                    result += trimmed + ". "
                    sentenceCount += 1
                    
                    if sentenceCount >= 2 && result.count > 150 {
                        break
                    }
                    if sentenceCount >= 3 {
                        break
                    }
                }
                
                if result.count < 100 {
                    if cleaned.count > 400 {
                        let index = cleaned.index(cleaned.startIndex, offsetBy: 400)
                        cleaned = String(cleaned[..<index])
                        if let lastPeriod = cleaned.lastIndex(of: ".") {
                            cleaned = String(cleaned[...lastPeriod])
                        } else {
                            cleaned += "..."
                        }
                        result = cleaned
                    } else {
                        result = cleaned
                    }
                }
                
                return result.trimmingCharacters(in: .whitespaces)
            }
        } catch {
            continue
        }
    }
    
    return nil
}

let fileManager = FileManager.default
let currentDir = fileManager.currentDirectoryPath
let jsonPath = "\(currentDir)/Claveo/Resources/musicDictionary.json"

guard let jsonData = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)) else {
    print("❌ Could not read musicDictionary.json")
    print("   Looking for: \(jsonPath)")
    exit(1)
}

guard var dictionary = try? JSONDecoder().decode(MusicDictionary.self, from: jsonData) else {
    print("❌ Could not decode JSON")
    exit(1)
}

print("📚 Found \(dictionary.terms.count) terms")
print("⏳ Starting enhancement (this will take a while due to rate limiting)...\n")
print("💡 Tip: This script will skip terms with definitions longer than 80 characters\n")

var enhanced = 0
var failed = 0
var skipped = 0

for (index, term) in dictionary.terms.enumerated() {
    let progress = Double(index + 1) / Double(dictionary.terms.count) * 100
    print("[\(String(format: "%.1f", progress))%] \(term.term)...", terminator: " ")
    
    // Skip if definition is already good
    if term.definition.count > 80 || term.definition.count < 20 {
        print("⏭️  Skipped")
        skipped += 1
        continue
    }
    
    if let enhancedDef = await fetchFromWikipedia(term: term.term, category: term.category) {
        dictionary.terms[index].definition = enhancedDef
        print("✅ Enhanced")
        enhanced += 1
    } else {
        print("❌ Failed")
        failed += 1
    }
    
    // Rate limiting - wait 300ms between requests
    try? await Task.sleep(nanoseconds: 300_000_000)
    
    // Save progress every 50 terms
    if (index + 1) % 50 == 0 {
        if let encoded = try? JSONEncoder().encode(dictionary) {
            let backupPath = "\(currentDir)/Claveo/Resources/musicDictionary_backup_\(index + 1).json"
            try? encoded.write(to: URL(fileURLWithPath: backupPath))
            print("💾 Progress saved (term \(index + 1))")
        }
    }
}

print("\n📊 Results:")
print("   ✅ Enhanced: \(enhanced)")
print("   ⏭️  Skipped: \(skipped)")
print("   ❌ Failed: \(failed)")

// Write back to file
if let encoded = try? JSONEncoder().encode(dictionary) {
    let backupPath = "\(currentDir)/Claveo/Resources/musicDictionary_backup.json"
    try? jsonData.write(to: URL(fileURLWithPath: backupPath))
    print("\n💾 Backup saved to: musicDictionary_backup.json")
    
    let outputPath = "\(currentDir)/Claveo/Resources/musicDictionary.json"
    try? encoded.write(to: URL(fileURLWithPath: outputPath))
    print("✅ Enhanced dictionary saved to: musicDictionary.json")
} else {
    print("\n❌ Failed to encode enhanced dictionary")
    exit(1)
}
