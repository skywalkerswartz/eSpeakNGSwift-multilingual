import Testing
@testable import eSpeakNGLib

// eSpeak NG uses global state internally (espeak_Initialize is a singleton),
// so all tests must run serially to avoid SIGABRT from concurrent initialization.
@Suite(.serialized)
struct eSpeakNGLibTests {

    // MARK: - English (baseline)

    @Test func englishUS() throws {
        let eSpeak = try eSpeakNG()
        try eSpeak.setLanguage(language: .enUS)
        let result = try eSpeak.phonemize(text: "Hello world!")
        #expect(result == "h_ə_l_ˈɔʊ w_ˈɜɹ_l_d")
    }

    @Test func englishGB() throws {
        let eSpeak = try eSpeakNG()
        try eSpeak.setLanguage(language: .enGB)
        let result = try eSpeak.phonemize(text: "Hello world!")
        #expect(!result.isEmpty)
        #expect(!result.contains("en-gb"))
    }

    // MARK: - New languages: smoke tests

    // These verify that phonemization runs without error and produces non-empty IPA output.
    // Exact string expectations should be added once validated against the Kokoro Python pipeline.

    @Test func spanishSmoke() throws {
        let eSpeak = try eSpeakNG()
        try eSpeak.setLanguage(language: .es)
        let result = try eSpeak.phonemize(text: "Hola mundo")
        #expect(!result.isEmpty)
        #expect(!result.contains("Hola"))
        print("Spanish phonemes: \(result)")
    }

    @Test func frenchSmoke() throws {
        let eSpeak = try eSpeakNG()
        try eSpeak.setLanguage(language: .frFR)
        let result = try eSpeak.phonemize(text: "Bonjour le monde")
        #expect(!result.isEmpty)
        #expect(!result.contains("Bonjour"))
        print("French phonemes: \(result)")
    }

    @Test func hindiSmoke() throws {
        let eSpeak = try eSpeakNG()
        try eSpeak.setLanguage(language: .hi)
        let result = try eSpeak.phonemize(text: "नमस्ते दुनिया")
        #expect(!result.isEmpty)
        print("Hindi phonemes: \(result)")
    }

    @Test func italianSmoke() throws {
        let eSpeak = try eSpeakNG()
        try eSpeak.setLanguage(language: .it)
        let result = try eSpeak.phonemize(text: "Ciao mondo")
        #expect(!result.isEmpty)
        #expect(!result.contains("Ciao"))
        print("Italian phonemes: \(result)")
    }

    @Test func portugueseSmoke() throws {
        let eSpeak = try eSpeakNG()
        try eSpeak.setLanguage(language: .ptBR)
        let result = try eSpeak.phonemize(text: "Olá mundo")
        #expect(!result.isEmpty)
        #expect(!result.contains("Olá"))
        print("Portuguese phonemes: \(result)")
    }

    @Test func chineseSmoke() throws {
        let eSpeak = try eSpeakNG()
        try eSpeak.setLanguage(language: .zh)
        let result = try eSpeak.phonemize(text: "你好世界")
        #expect(!result.isEmpty)
        print("Chinese phonemes: \(result)")
    }

    @Test func japaneseSmoke() throws {
        let eSpeak = try eSpeakNG()
        try eSpeak.setLanguage(language: .ja)
        let result = try eSpeak.phonemize(text: "こんにちは世界")
        #expect(!result.isEmpty)
        print("Japanese phonemes: \(result)")
    }

    // MARK: - Language switching

    @Test func languageSwitching() throws {
        let eSpeak = try eSpeakNG()

        try eSpeak.setLanguage(language: .enUS)
        let english = try eSpeak.phonemize(text: "Hello")

        try eSpeak.setLanguage(language: .es)
        let spanish = try eSpeak.phonemize(text: "Hola")

        try eSpeak.setLanguage(language: .frFR)
        let french = try eSpeak.phonemize(text: "Bonjour")

        // Each language should produce distinct output
        #expect(english != spanish)
        #expect(english != french)
        #expect(spanish != french)
    }

    // MARK: - Post-processing: verify English-specific mappings don't bleed into other languages

    @Test func spanishEIsNotMappedToA() throws {
        // In English, eSpeak outputs bare "e" which Kokoro maps to "A" (representing /eɪ/).
        // In Spanish, "e" is a genuine standalone vowel and must be preserved.
        let eSpeak = try eSpeakNG()
        try eSpeak.setLanguage(language: .es)
        // "mesa" contains the Spanish /e/ vowel
        let result = try eSpeak.phonemize(text: "mesa")
        // The Spanish /e/ must not have been replaced with Kokoro's English "A"
        #expect(result.contains("e") || result.contains("ɛ"))
        print("Spanish 'mesa' phonemes: \(result)")
    }

    @Test func spanishRIsPreserved() throws {
        // In English, eSpeak "r" is mapped to "ɹ". In Spanish, "r" is a tap/trill and must remain.
        let eSpeak = try eSpeakNG()
        try eSpeak.setLanguage(language: .es)
        // "pero" contains the Spanish /ɾ/ (tap)
        let result = try eSpeak.phonemize(text: "pero")
        // Should not have converted Spanish /r/ to English "ɹ"
        #expect(!result.contains("ɹ"))
        print("Spanish 'pero' phonemes: \(result)")
    }

    @Test func frenchNasalVowelMapped() throws {
        // French "bon" contains /ɔ̃/ which should be mapped to 'C' for Kokoro
        let eSpeak = try eSpeakNG()
        try eSpeak.setLanguage(language: .frFR)
        let result = try eSpeak.phonemize(text: "bon")
        // Raw ɔ̃ (ɔ + U+0303) should have been converted to 'C'
        #expect(result.contains("C"))
        #expect(!result.contains("ɔ\u{0303}"))
        print("French 'bon' phonemes: \(result)")
    }

    // To discover available language codes in the xcframework, temporarily add a test
    // that mirrors the eSpeakNG instance and prints its languageMapping dictionary.
}
