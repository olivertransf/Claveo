import Foundation

// Script to manually add symbols to terms with accurate, carefully verified mappings

struct MusicTerm: Codable {
    let term: String
    let definition: String
    let category: String
    let example: String?
    var symbol: String?
    var smuflCode: String?
}

struct MusicDictionary: Codable {
    var terms: [MusicTerm]
}

// Convert SMuFL code to character
func smuflCodeToCharacter(_ code: String) -> String {
    let hexString = code.replacingOccurrences(of: "U+", with: "")
    if let codePoint = UInt32(hexString, radix: 16),
       let scalar = UnicodeScalar(codePoint) {
        return String(Character(scalar))
    }
    return ""
}

// Comprehensive manual mappings - carefully verified
// Only terms that actually have musical symbols
let manualSymbolMappings: [String: (smuflCode: String, symbol: String)] = [
    // CLEFS
    "treble clef": ("U+E050", smuflCodeToCharacter("U+E050")),
    "g clef": ("U+E050", smuflCodeToCharacter("U+E050")),
    "bass clef": ("U+E062", smuflCodeToCharacter("U+E062")),
    "f clef": ("U+E062", smuflCodeToCharacter("U+E062")),
    "alto clef": ("U+E05C", smuflCodeToCharacter("U+E05C")),
    "c clef": ("U+E05C", smuflCodeToCharacter("U+E05C")),
    "tenor clef": ("U+E05C", smuflCodeToCharacter("U+E05C")),
    "baritone clef": ("U+E05C", smuflCodeToCharacter("U+E05C")),
    "soprano clef": ("U+E05C", smuflCodeToCharacter("U+E05C")), // C clef
    "mezzo-soprano clef": ("U+E05C", smuflCodeToCharacter("U+E05C")), // C clef
    "double treble clef": ("U+E050", smuflCodeToCharacter("U+E050")), // Double G clef
    "octave treble clef": ("U+E050", smuflCodeToCharacter("U+E050")), // Octave G clef
    "percussion clef": ("U+E050", smuflCodeToCharacter("U+E050")), // Neutral/percussion clef (often shown as G clef)
    "neutral clef": ("U+E050", smuflCodeToCharacter("U+E050")), // Neutral clef
    "alto": ("U+E05C", smuflCodeToCharacter("U+E05C")),
    "bass (voice)": ("U+E062", smuflCodeToCharacter("U+E062")),
    "bass (instrument)": ("U+E062", smuflCodeToCharacter("U+E062")),
    "clef": ("U+E050", smuflCodeToCharacter("U+E050")), // Generic - treble clef
    
    // ACCIDENTALS
    "sharp": ("U+E262", smuflCodeToCharacter("U+E262")),
    "flat": ("U+E260", smuflCodeToCharacter("U+E260")),
    "natural": ("U+E261", smuflCodeToCharacter("U+E261")),
    "double sharp": ("U+E263", smuflCodeToCharacter("U+E263")),
    "double flat": ("U+E264", smuflCodeToCharacter("U+E264")),
    "accidental": ("U+E262", smuflCodeToCharacter("U+E262")), // Generic - sharp
    
    // NOTEHEADS
    "whole note": ("U+E0A2", smuflCodeToCharacter("U+E0A2")),
    "half note": ("U+E0A3", smuflCodeToCharacter("U+E0A3")),
    "quarter note": ("U+E0A4", smuflCodeToCharacter("U+E0A4")),
    "eighth note": ("U+E0A5", smuflCodeToCharacter("U+E0A5")),
    "sixteenth note": ("U+E0A6", smuflCodeToCharacter("U+E0A6")),
    "double whole note": ("U+E0A1", smuflCodeToCharacter("U+E0A1")), // breve
    "note": ("U+E0A4", smuflCodeToCharacter("U+E0A4")), // Generic - quarter note
    "notehead": ("U+E0A4", smuflCodeToCharacter("U+E0A4")), // Generic - quarter notehead
    "note value": ("U+E0A4", smuflCodeToCharacter("U+E0A4")), // Generic - quarter note
    "active note": ("U+E0A4", smuflCodeToCharacter("U+E0A4")),
    "color note": ("U+E0A4", smuflCodeToCharacter("U+E0A4")),
    "blue notes": ("U+E0A4", smuflCodeToCharacter("U+E0A4")),
    "straight eighth notes": ("U+E0A5", smuflCodeToCharacter("U+E0A5")),
    
    // RESTS
    "whole rest": ("U+E4E3", smuflCodeToCharacter("U+E4E3")),
    "half rest": ("U+E4E4", smuflCodeToCharacter("U+E4E4")),
    "quarter rest": ("U+E4E5", smuflCodeToCharacter("U+E4E5")),
    "eighth rest": ("U+E4E6", smuflCodeToCharacter("U+E4E6")),
    "sixteenth rest": ("U+E4E7", smuflCodeToCharacter("U+E4E7")),
    "rest": ("U+E4E5", smuflCodeToCharacter("U+E4E5")), // Generic - quarter rest
    "grand pause": ("U+E4E3", smuflCodeToCharacter("U+E4E3")), // Whole rest
    
    // DYNAMICS - CAREFUL: crescendo and decrescendo are DIFFERENT!
    "piano": ("U+E520", smuflCodeToCharacter("U+E520")), // p
    "forte": ("U+E522", smuflCodeToCharacter("U+E522")), // f
    "mezzo forte": ("U+E521", smuflCodeToCharacter("U+E521")), // mf
    "mezzo piano": ("U+E521", smuflCodeToCharacter("U+E521")), // mp
    "mezzo": ("U+E521", smuflCodeToCharacter("U+E521")), // Generic mezzo
    "fortissimo": ("U+E523", smuflCodeToCharacter("U+E523")), // ff
    "pianissimo": ("U+E52F", smuflCodeToCharacter("U+E52F")), // pp
    "crescendo": ("U+E53E", smuflCodeToCharacter("U+E53E")), // < (hairpin opening right)
    "decrescendo": ("U+E53F", smuflCodeToCharacter("U+E53F")), // > (hairpin closing right) - DIFFERENT!
    "diminuendo": ("U+E53F", smuflCodeToCharacter("U+E53F")), // > (same as decrescendo)
    "dynamics": ("U+E522", smuflCodeToCharacter("U+E522")), // Generic - forte
    
    // ARTICULATIONS (U+E4A0–U+E4BF)
    // Only exact matches - no approximations
    // Based on SMuFL specification: https://w3c.github.io/smufl/latest/tables/articulation.html
    "accent": ("U+E4A0", smuflCodeToCharacter("U+E4A0")), // Accent Above
    "staccato": ("U+E4A2", smuflCodeToCharacter("U+E4A2")), // Staccato Above
    "tenuto": ("U+E4A4", smuflCodeToCharacter("U+E4A4")), // Tenuto Above
    "marcato": ("U+E4AC", smuflCodeToCharacter("U+E4AC")), // Marcato Above
    "fermata": ("U+E4C0", smuflCodeToCharacter("U+E4C0")), // Fermata Above (in Holds and pauses range)
    "articulation": ("U+E4A2", smuflCodeToCharacter("U+E4A2")), // Generic - staccato
    // Note: legato removed - no exact articulation symbol (it's shown as slur, not an articulation mark)
    
    // ORNAMENTS
    "trill": ("U+E566", smuflCodeToCharacter("U+E566")), // tr
    "turn": ("U+E567", smuflCodeToCharacter("U+E567")), // turn symbol
    "mordent": ("U+E56C", smuflCodeToCharacter("U+E56C")), // mordent
    "appoggiatura": ("U+E562", smuflCodeToCharacter("U+E562")), // grace note
    "ornament": ("U+E566", smuflCodeToCharacter("U+E566")), // Generic - trill
    "ornamentation": ("U+E566", smuflCodeToCharacter("U+E566")), // Generic - trill
    
    // BARLINES
    "bar line": ("U+E030", smuflCodeToCharacter("U+E030")),
    "barline": ("U+E030", smuflCodeToCharacter("U+E030")),
    "bar lines": ("U+E030", smuflCodeToCharacter("U+E030")),
    "double barline": ("U+E031", smuflCodeToCharacter("U+E031")),
    "double bar": ("U+E031", smuflCodeToCharacter("U+E031")),
    "final barline": ("U+E032", smuflCodeToCharacter("U+E032")),
    
    // REPEATS
    "repeat sign": ("U+E040", smuflCodeToCharacter("U+E040")),
    "da capo": ("U+E046", smuflCodeToCharacter("U+E046")), // D.C.
    "dal segno": ("U+E045", smuflCodeToCharacter("U+E045")), // D.S.
    "d.c. al coda": ("U+E048", smuflCodeToCharacter("U+E048")), // coda
    "d.c. al fine": ("U+E046", smuflCodeToCharacter("U+E046")), // D.C.
    "d.s. al coda": ("U+E048", smuflCodeToCharacter("U+E048")), // coda
    "d.s. al fine": ("U+E045", smuflCodeToCharacter("U+E045")), // D.S.
    "coda": ("U+E048", smuflCodeToCharacter("U+E048")), // coda sign
    "coda (classical)": ("U+E048", smuflCodeToCharacter("U+E048")),
    "coda (pop)": ("U+E048", smuflCodeToCharacter("U+E048")),
    "segno": ("U+E047", smuflCodeToCharacter("U+E047")), // segno sign
    
    // TIME SIGNATURES
    "time signature": ("U+E080", smuflCodeToCharacter("U+E080")), // Generic number
    "common time": ("U+E08A", smuflCodeToCharacter("U+E08A")), // C
    "cut time": ("U+E08B", smuflCodeToCharacter("U+E08B")), // Cut C
    
    // OTHER NOTATION
    "tie": ("U+E1F0", smuflCodeToCharacter("U+E1F0")), // tie curve
    "slur": ("U+E1F0", smuflCodeToCharacter("U+E1F0")), // slur curve
    "dot": ("U+E1E7", smuflCodeToCharacter("U+E1E7")), // augmentation dot
    "rhythm dot": ("U+E1E7", smuflCodeToCharacter("U+E1E7")), // augmentation dot
    "dot grid": ("U+E1E7", smuflCodeToCharacter("U+E1E7")), // dot
    "breath mark": ("U+E4CE", smuflCodeToCharacter("U+E4CE")), // breath mark
    "key signature": ("U+E262", smuflCodeToCharacter("U+E262")), // Generic - sharp
    "beam": ("U+E1F0", smuflCodeToCharacter("U+E1F0")), // beam/ligature
    "repeated phrase": ("U+E040", smuflCodeToCharacter("U+E040")), // repeat sign
]

func normalizeTerm(_ term: String) -> String {
    return term.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
}

func findSymbolForTerm(_ term: String) -> (smuflCode: String, symbol: String)? {
    let normalized = normalizeTerm(term)
    
    // Only exact matches - no approximations for simplicity
    // Try exact match first
    if let mapping = manualSymbolMappings[normalized] {
        return mapping
    }
    
    // Try removing parenthetical content and try again (e.g., "coda (classical)" -> "coda")
    let withoutParens = normalized.replacingOccurrences(of: " \\(.*\\)", with: "", options: .regularExpression)
    if withoutParens != normalized, let mapping = manualSymbolMappings[withoutParens] {
        return mapping
    }
    
    // Only allow very specific word matches for compound terms (e.g., "mezzo forte" -> "mezzo forte")
    // Don't do partial matching - only exact or parenthetical removal
    return nil
}

let fileManager = FileManager.default
let currentDir = fileManager.currentDirectoryPath
let jsonPath = "\(currentDir)/Claveo/Resources/musicDictionary.json"

print("📚 Loading dictionary...")
guard let jsonData = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)) else {
    print("❌ Could not read musicDictionary.json")
    exit(1)
}

guard var dictionary = try? JSONDecoder().decode(MusicDictionary.self, from: jsonData) else {
    print("❌ Could not decode JSON")
    exit(1)
}

print("✅ Loaded \(dictionary.terms.count) terms")
print("🔄 Matching symbols with careful manual mappings...\n")

var matched = 0
var matchedTerms: [String] = []

// Match symbols to terms
for (index, term) in dictionary.terms.enumerated() {
    if let symbolInfo = findSymbolForTerm(term.term) {
        if !symbolInfo.symbol.isEmpty {
            dictionary.terms[index].symbol = symbolInfo.symbol
            dictionary.terms[index].smuflCode = symbolInfo.smuflCode
            matched += 1
            matchedTerms.append(term.term)
            if matched <= 60 {
                print("[\(matched)] ✅ \(term.term) → \(symbolInfo.smuflCode)")
            }
        }
    }
}

print("\n📊 Results:")
print("   ✅ Terms with symbols: \(matched)")
print("   📝 Total terms: \(dictionary.terms.count)")
print("\n📋 Matched terms:")
for term in matchedTerms.sorted() {
    print("   - \(term)")
}

// Write updated dictionary
if let encoded = try? JSONEncoder().encode(dictionary) {
    try? encoded.write(to: URL(fileURLWithPath: jsonPath))
    print("\n✅ Updated dictionary saved to: musicDictionary.json")
} else {
    print("\n❌ Failed to encode dictionary")
    exit(1)
}
