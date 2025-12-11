import Foundation

// Script to replace entire dictionary with terms from Open Music Theory glossary

struct MusicTerm: Codable {
    let term: String
    let definition: String
    let category: String
    let example: String?
}

struct MusicDictionary: Codable {
    let terms: [MusicTerm]
}

func fetchGlossary() async -> [(term: String, definition: String)]? {
    guard let url = URL(string: "https://viva.pressbooks.pub/openmusictheory/back-matter/glossary/") else {
        return nil
    }
    
    do {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        var glossary: [(term: String, definition: String)] = []
        
        // Parse HTML to extract glossary entries
        let dtPattern = "<dt[^>]*>(.*?)</dt>"
        let ddPattern = "<dd[^>]*>(.*?)</dd>"
        
        let dtRegex = try NSRegularExpression(pattern: dtPattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
        let ddRegex = try NSRegularExpression(pattern: ddPattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
        
        let nsString = html as NSString
        let dtMatches = dtRegex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
        let ddMatches = ddRegex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
        
        // Match dt and dd pairs
        for (index, dtMatch) in dtMatches.enumerated() {
            if index < ddMatches.count {
                let termRange = dtMatch.range(at: 1)
                let defRange = ddMatches[index].range(at: 1)
                
                var term = nsString.substring(with: termRange)
                var definition = nsString.substring(with: defRange)
                
                // Clean HTML tags
                term = cleanHTML(term)
                definition = cleanHTML(definition)
                
                term = term.trimmingCharacters(in: .whitespacesAndNewlines)
                definition = definition.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !term.isEmpty && !definition.isEmpty {
                    glossary.append((term: term, definition: definition))
                }
            }
        }
        
        return glossary
    } catch {
        print("Error fetching glossary: \(error)")
        return nil
    }
}

func cleanHTML(_ html: String) -> String {
    var cleaned = html
    
    // Remove HTML tags
    cleaned = cleaned.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    
    // Decode HTML entities
    cleaned = cleaned.replacingOccurrences(of: "&nbsp;", with: " ")
    cleaned = cleaned.replacingOccurrences(of: "&amp;", with: "&")
    cleaned = cleaned.replacingOccurrences(of: "&lt;", with: "<")
    cleaned = cleaned.replacingOccurrences(of: "&gt;", with: ">")
    cleaned = cleaned.replacingOccurrences(of: "&quot;", with: "\"")
    cleaned = cleaned.replacingOccurrences(of: "&#39;", with: "'")
    cleaned = cleaned.replacingOccurrences(of: "&apos;", with: "'")
    cleaned = cleaned.replacingOccurrences(of: "&ndash;", with: "–")
    cleaned = cleaned.replacingOccurrences(of: "&mdash;", with: "—")
    
    // Clean up whitespace
    cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    
    return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
}

func categorizeTerm(_ term: String, _ definition: String) -> String {
    let termLower = term.lowercased()
    let defLower = definition.lowercased()
    
    // Tempo markings
    if termLower.contains("tempo") || termLower.contains("allegro") || termLower.contains("adagio") || 
       termLower.contains("andante") || termLower.contains("presto") || termLower.contains("largo") ||
       termLower.contains("vivace") || termLower.contains("moderato") || termLower.contains("lento") ||
       termLower.contains("accelerando") || termLower.contains("ritardando") || termLower.contains("rallentando") {
        return "Tempo"
    }
    
    // Dynamics
    if termLower.contains("piano") || termLower.contains("forte") || termLower.contains("mezzo") ||
       termLower.contains("crescendo") || termLower.contains("decrescendo") || termLower.contains("diminuendo") ||
       termLower.contains("dynamics") || defLower.contains("volume") || defLower.contains("loud") ||
       defLower.contains("soft") || defLower.contains("quiet") {
        return "Dynamics"
    }
    
    // Articulation
    if termLower.contains("staccato") || termLower.contains("legato") || termLower.contains("marcato") ||
       termLower.contains("tenuto") || termLower.contains("accent") || termLower.contains("fermata") ||
       termLower.contains("articulation") || defLower.contains("detached") || defLower.contains("connected") {
        return "Articulation"
    }
    
    // Ornaments
    if termLower.contains("trill") || termLower.contains("mordent") || termLower.contains("turn") ||
       termLower.contains("appoggiatura") || termLower.contains("ornament") || termLower.contains("embellishment") {
        return "Ornamentation"
    }
    
    // Notation
    if termLower.contains("clef") || termLower.contains("staff") || termLower.contains("note") ||
       termLower.contains("rest") || termLower.contains("sharp") || termLower.contains("flat") ||
       termLower.contains("natural") || termLower.contains("time signature") || termLower.contains("key signature") ||
       termLower.contains("bar") || termLower.contains("measure") || termLower.contains("notation") ||
       termLower.contains("ledger") || termLower.contains("accidental") {
        return "Notation"
    }
    
    // Theory
    if termLower.contains("scale") || termLower.contains("chord") || termLower.contains("triad") ||
       termLower.contains("interval") || termLower.contains("harmony") || termLower.contains("melody") ||
       termLower.contains("mode") || termLower.contains("cadence") || termLower.contains("progression") ||
       termLower.contains("key") || termLower.contains("tonic") || termLower.contains("dominant") ||
       termLower.contains("subdominant") || termLower.contains("inversion") || termLower.contains("roman numeral") ||
       termLower.contains("figured bass") || termLower.contains("counterpoint") || termLower.contains("voice leading") ||
       termLower.contains("texture") || termLower.contains("monophony") || termLower.contains("homophony") ||
       termLower.contains("polyphony") || defLower.contains("pitch class") || defLower.contains("scale degree") {
        return "Theory"
    }
    
    // Form
    if termLower.contains("form") || termLower.contains("sonata") || termLower.contains("rondo") ||
       termLower.contains("fugue") || termLower.contains("canon") || termLower.contains("variation") ||
       termLower.contains("theme") || termLower.contains("phrase") || termLower.contains("section") ||
       termLower.contains("exposition") || termLower.contains("development") || termLower.contains("recapitulation") ||
       termLower.contains("verse") || termLower.contains("chorus") {
        return "Form"
    }
    
    // Rhythm
    if termLower.contains("rhythm") || termLower.contains("beat") || termLower.contains("meter") ||
       termLower.contains("syncopation") || termLower.contains("tuplet") || termLower.contains("triplet") ||
       termLower.contains("downbeat") || termLower.contains("upbeat") {
        return "Rhythm"
    }
    
    // General/Other
    return "General"
}

let fileManager = FileManager.default
let currentDir = fileManager.currentDirectoryPath
let jsonPath = "\(currentDir)/Claveo/Resources/musicDictionary.json"

print("🌐 Fetching glossary from Open Music Theory...")

guard let glossaryEntries = await fetchGlossary() else {
    print("❌ Failed to fetch glossary")
    exit(1)
}

print("✅ Fetched \(glossaryEntries.count) glossary entries")
print("🔄 Categorizing and creating dictionary...\n")

// Create backup first
if let existingData = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)) {
    let backupPath = "\(currentDir)/Claveo/Resources/musicDictionary_backup_\(Int(Date().timeIntervalSince1970)).json"
    try? existingData.write(to: URL(fileURLWithPath: backupPath))
    print("💾 Backup saved to: \(backupPath)\n")
}

// Convert to MusicTerm array
let terms = glossaryEntries.map { entry -> MusicTerm in
    let category = categorizeTerm(entry.term, entry.definition)
    return MusicTerm(
        term: entry.term,
        definition: entry.definition,
        category: category,
        example: nil
    )
}

let dictionary = MusicDictionary(terms: terms)

print("📊 Created dictionary with \(terms.count) terms")
print("📁 Categories:")
let categories = Dictionary(grouping: terms) { $0.category }
for (category, categoryTerms) in categories.sorted(by: { $0.key < $1.key }) {
    print("   - \(category): \(categoryTerms.count) terms")
}

// Write dictionary
if let encoded = try? JSONEncoder().encode(dictionary) {
    try? encoded.write(to: URL(fileURLWithPath: jsonPath))
    print("\n✅ Dictionary saved to: musicDictionary.json")
    print("   ✨ All terms from Open Music Theory glossary")
} else {
    print("\n❌ Failed to encode dictionary")
    exit(1)
}

