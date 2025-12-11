import Foundation

// Script to keep ONLY exact matches - remove all non-exact mappings

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

// Load dictionary to get exact term list
let fileManager = FileManager.default
let currentDir = fileManager.currentDirectoryPath
let jsonPath = "\(currentDir)/Claveo/Resources/musicDictionary.json"

guard let jsonData = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)),
      var dictionary = try? JSONDecoder().decode(MusicDictionary.self, from: jsonData) else {
    print("❌ Could not load dictionary")
    exit(1)
}

let exactTerms = Set(dictionary.terms.map { $0.term.lowercased() })

// Only mappings that exist as exact terms in the dictionary
let exactMappings: [String: (smuflCode: String, symbol: String)] = [
    // CLEFS
    "treble clef": ("U+E050", smuflCodeToCharacter("U+E050")),
    "bass clef": ("U+E062", smuflCodeToCharacter("U+E062")),
    "alto clef": ("U+E05C", smuflCodeToCharacter("U+E05C")),
    "tenor clef": ("U+E05C", smuflCodeToCharacter("U+E05C")),
    "baritone clef": ("U+E05C", smuflCodeToCharacter("U+E05C")),
    "soprano clef": ("U+E05C", smuflCodeToCharacter("U+E05C")),
    "mezzo-soprano clef": ("U+E05C", smuflCodeToCharacter("U+E05C")),
    "double treble clef": ("U+E050", smuflCodeToCharacter("U+E050")),
    "octave treble clef": ("U+E050", smuflCodeToCharacter("U+E050")),
    "percussion clef": ("U+E050", smuflCodeToCharacter("U+E050")),
    "neutral clef": ("U+E050", smuflCodeToCharacter("U+E050")),
    "alto": ("U+E05C", smuflCodeToCharacter("U+E05C")),
    "bass (voice)": ("U+E062", smuflCodeToCharacter("U+E062")),
    "bass (instrument)": ("U+E062", smuflCodeToCharacter("U+E062")),
    "clef": ("U+E050", smuflCodeToCharacter("U+E050")),
    
    // ACCIDENTALS
    "sharp": ("U+E262", smuflCodeToCharacter("U+E262")),
    "flat": ("U+E260", smuflCodeToCharacter("U+E260")),
    "natural": ("U+E261", smuflCodeToCharacter("U+E261")),
    "double sharp": ("U+E263", smuflCodeToCharacter("U+E263")),
    "double flat": ("U+E264", smuflCodeToCharacter("U+E264")),
    "accidental": ("U+E262", smuflCodeToCharacter("U+E262")),
    
    // NOTEHEADS
    "whole note": ("U+E0A2", smuflCodeToCharacter("U+E0A2")),
    "half note": ("U+E0A3", smuflCodeToCharacter("U+E0A3")),
    "quarter note": ("U+E0A4", smuflCodeToCharacter("U+E0A4")),
    "eighth note": ("U+E0A5", smuflCodeToCharacter("U+E0A5")),
    "sixteenth note": ("U+E0A6", smuflCodeToCharacter("U+E0A6")),
    "double whole note": ("U+E0A1", smuflCodeToCharacter("U+E0A1")),
    "note": ("U+E0A4", smuflCodeToCharacter("U+E0A4")),
    "notehead": ("U+E0A4", smuflCodeToCharacter("U+E0A4")),
    "note value": ("U+E0A4", smuflCodeToCharacter("U+E0A4")),
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
    "rest": ("U+E4E5", smuflCodeToCharacter("U+E4E5")),
    
    // DYNAMICS
    "piano": ("U+E520", smuflCodeToCharacter("U+E520")),
    "forte": ("U+E522", smuflCodeToCharacter("U+E522")),
    "mezzo": ("U+E521", smuflCodeToCharacter("U+E521")),
    "crescendo": ("U+E53E", smuflCodeToCharacter("U+E53E")),
    "decrescendo": ("U+E53F", smuflCodeToCharacter("U+E53F")),
    "diminuendo": ("U+E53F", smuflCodeToCharacter("U+E53F")),
    "dynamics": ("U+E522", smuflCodeToCharacter("U+E522")),
    
    // ARTICULATIONS
    "accent": ("U+E4A0", smuflCodeToCharacter("U+E4A0")),
    "staccato": ("U+E4A2", smuflCodeToCharacter("U+E4A2")),
    "tenuto": ("U+E4A4", smuflCodeToCharacter("U+E4A4")),
    "marcato": ("U+E4AC", smuflCodeToCharacter("U+E4AC")),
    "fermata": ("U+E4C0", smuflCodeToCharacter("U+E4C0")),
    "articulation": ("U+E4A2", smuflCodeToCharacter("U+E4A2")),
    
    // ORNAMENTS
    "turn": ("U+E567", smuflCodeToCharacter("U+E567")),
    "appoggiatura": ("U+E562", smuflCodeToCharacter("U+E562")),
    
    // BARLINES
    "bar lines": ("U+E030", smuflCodeToCharacter("U+E030")),
    
    // REPEATS
    "repeat sign": ("U+E040", smuflCodeToCharacter("U+E040")),
    "d.c. al coda": ("U+E048", smuflCodeToCharacter("U+E048")),
    "d.c. al fine": ("U+E046", smuflCodeToCharacter("U+E046")),
    "d.s. al coda": ("U+E048", smuflCodeToCharacter("U+E048")),
    "d.s. al fine": ("U+E045", smuflCodeToCharacter("U+E045")),
    "coda (classical)": ("U+E048", smuflCodeToCharacter("U+E048")),
    "coda (pop)": ("U+E048", smuflCodeToCharacter("U+E048")),
    "repeated phrase": ("U+E040", smuflCodeToCharacter("U+E040")),
    
    // TIME SIGNATURES
    // Note: "time signature" removed - it's a generic term, not an actual time signature symbol
    
    // OTHER NOTATION
    "tie": ("U+E1F0", smuflCodeToCharacter("U+E1F0")),
    "slur": ("U+E1F0", smuflCodeToCharacter("U+E1F0")),
    "rhythm dot": ("U+E1E7", smuflCodeToCharacter("U+E1E7")),
    "dot grid": ("U+E1E7", smuflCodeToCharacter("U+E1E7")),
    "breath mark": ("U+E4CE", smuflCodeToCharacter("U+E4CE")),
    "key signature": ("U+E262", smuflCodeToCharacter("U+E262")),
    "beam": ("U+E1F0", smuflCodeToCharacter("U+E1F0")),
]

print("🧹 Cleaning symbols - keeping only exact matches...")
print("📚 Dictionary has \(dictionary.terms.count) terms")
print("🎯 Exact mappings available: \(exactMappings.count)\n")

// Remove all symbols first
for i in 0..<dictionary.terms.count {
    dictionary.terms[i].symbol = nil
    dictionary.terms[i].smuflCode = nil
}

var matched = 0

// Only add symbols for exact matches
for (index, term) in dictionary.terms.enumerated() {
    let normalized = term.term.lowercased()
    
    // Try exact match
    if let mapping = exactMappings[normalized] {
        dictionary.terms[index].symbol = mapping.symbol
        dictionary.terms[index].smuflCode = mapping.smuflCode
        matched += 1
        continue
    }
    
    // Try removing parenthetical content
    let withoutParens = normalized.replacingOccurrences(of: " \\(.*\\)", with: "", options: .regularExpression)
    if withoutParens != normalized, let mapping = exactMappings[withoutParens] {
        dictionary.terms[index].symbol = mapping.symbol
        dictionary.terms[index].smuflCode = mapping.smuflCode
        matched += 1
    }
}

print("✅ Matched \(matched) terms with exact symbols")
print("📝 Total terms: \(dictionary.terms.count)")

// Save updated dictionary
if let encoded = try? JSONEncoder().encode(dictionary) {
    try? encoded.write(to: URL(fileURLWithPath: jsonPath))
    print("\n✅ Updated dictionary saved - only exact matches kept")
} else {
    print("\n❌ Failed to encode dictionary")
    exit(1)
}

