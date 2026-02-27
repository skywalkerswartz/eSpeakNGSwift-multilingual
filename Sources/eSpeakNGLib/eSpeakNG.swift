import ESpeakNG

//  Kokoro-tts-lib
//
import Foundation

// ESpeakNG wrapper for phonemizing the text strings
public final class eSpeakNG {
  private var languageMapping: [String: String] = [:]
  private var language: Language = .none

  public enum ESpeakNGEngineError: Error {
    case dataBundleNotFound
    case couldNotInitialize
    case languageNotFound
    case internalError
    case languageNotSet
    case couldNotPhonemize
  }

  // Available languages
  public enum Language: String, CaseIterable {
    case none = ""
    case enUS = "en-us"
    case enGB = "en-gb"
    case es = "es"        // Spanish
    case frFR = "fr-fr"   // French
    case hi = "hi"        // Hindi
    case it = "it"        // Italian
    case ptBR = "pt-br"   // Brazilian Portuguese
    case zh = "cmn"       // Mandarin Chinese (eSpeak NG uses "cmn")
    case ja = "ja"        // Japanese
  }

  // After constructing the wrapper, call setLanguage() before phonemizing any text
  public init() throws {
    if let bundleURLStr = findDataBundlePath() {
      let initOK = espeak_Initialize(AUDIO_OUTPUT_PLAYBACK, 0, bundleURLStr, 0)

      if initOK != Constants.successAudioSampleRate {
        throw ESpeakNGEngineError.couldNotInitialize
      }

      var languageList: Set<String> = []
      let voiceList = espeak_ListVoices(nil)
      var index = 0
      while let voicePointer = voiceList?.advanced(by: index).pointee {
        let voice = voicePointer.pointee
        if let cLang = voice.languages {
          let language = String(cString: cLang, encoding: .utf8)!
            .replacingOccurrences(of: "\u{05}", with: "")
            .replacingOccurrences(of: "\u{02}", with: "")
          languageList.insert(language)

          if let cName = voice.identifier {
            let name = String(cString: cName, encoding: .utf8)!
              .replacingOccurrences(of: "\u{05}", with: "")
              .replacingOccurrences(of: "\u{02}", with: "")
            languageMapping[language] = name
          }
        }

        index += 1
      }

      // Validate that at minimum English is available (sanity check on the data bundle).
      // Individual language availability is checked lazily in setLanguage().
      if !languageList.contains(Language.enUS.rawValue) {
        throw ESpeakNGEngineError.languageNotFound
      }
    } else {
      throw ESpeakNGEngineError.dataBundleNotFound
    }
  }

  // Destructor
  deinit {
    _ = espeak_Terminate()
  }

  // Sets the language that will be used for phonemizing
  // If the function returns without throwing an exception then consider new language set!
  public func setLanguage(language: Language) throws {
    guard let name = languageMapping[language.rawValue]
    else {
      throw ESpeakNGEngineError.languageNotFound
    }

    let result = espeak_SetVoiceByName((name as NSString).utf8String)

    if result == EE_NOT_FOUND {
      throw ESpeakNGEngineError.languageNotFound
    } else if result != EE_OK {
      throw ESpeakNGEngineError.internalError
    }

    self.language = language
  }

  // Phonemizes the text string that can then be passed to the next stage
  public func phonemize(text: String) throws -> String {
    guard language != .none else {
      throw ESpeakNGEngineError.languageNotSet
    }

    guard !text.isEmpty else {
      return ""
    }

    var textPtr = UnsafeRawPointer((text as NSString).utf8String)
    let phonemes_mode = Int32((Int32(Character("_").asciiValue!) << 8) | 0x02)
    let result = withUnsafeMutablePointer(to: &textPtr) { ptr in
      var resultWords: [String] = []
      while ptr.pointee != nil {
        let result = ESpeakNG.espeak_TextToPhonemes(ptr, espeakCHARS_UTF8, phonemes_mode)
        if let result {
          resultWords.append(String(cString: result, encoding: .utf8)!)
        }
      }
      return resultWords
    }

    if !result.isEmpty {
      return postProcessPhonemes(result.joined(separator: " "))
    } else {
      throw ESpeakNGEngineError.couldNotPhonemize
    }
  }

  // Post processes manually phonemes before returning them
  private func postProcessPhonemes(_ phonemes: String) -> String {
    var result = phonemes.trimmingCharacters(in: .whitespacesAndNewlines)

    // Strip language-change annotations that eSpeak NG injects into the phoneme stream.
    // These appear as "(Japanese)", "(Mandarin Chinese)", "(in Japanese)" etc. at the
    // start of the output when switching to a CJK script. Without this stripping they
    // pass through to Kokoro, which speaks them as English words before the actual speech.
    // The pattern matches ASCII-only parentheticals (language names are ASCII; legitimate
    // IPA optional-sound notation uses Unicode letters like ŋ, ɹ that won't match [A-Za-z]).
    result = result.replacingOccurrences(of: "\\([A-Za-z][a-zA-Z ]+\\)", with: "",
                                         options: .regularExpression)
    result = result.trimmingCharacters(in: .whitespaces)
    #if DEBUG
    if language == .ja || language == .zh {
      print("[eSpeakNG] post-strip phonemes for '\(language)': '\(result.prefix(120))'")
    }
    #endif

    result = result.replacingOccurrences(of: "(\\S)\u{0329}", with: "ᵊ$1", options: .regularExpression)
    result = result.replacingOccurrences(of: "\u{0329}", with: "")

    switch language {
    case .es, .frFR, .hi, .it, .ptBR, .zh, .ja:
      // Non-English: apply only the safe cross-language substitutions (diphthong/affricate
      // tie-marker cleanup), then nasal vowel normalization. Do NOT apply English-specific
      // mappings like e->A or r->ɹ which would corrupt these phonemes.
      for (old, new) in Constants.E2M_MULTI {
        result = result.replacingOccurrences(of: old, with: new)
      }
      // Map nasal vowels to Kokoro's single-character representations
      result = result.replacingOccurrences(of: "œ\u{0303}", with: "B")  // œ̃
      result = result.replacingOccurrences(of: "ɔ\u{0303}", with: "C")  // ɔ̃
      result = result.replacingOccurrences(of: "ɑ\u{0303}", with: "D")  // ɑ̃
      result = result.replacingOccurrences(of: "ɛ\u{0303}", with: "E")  // ɛ̃
      // Remove dental diacritic (U+032A) and tie bar (U+0361)
      result = result.replacingOccurrences(of: "\u{032A}", with: "")
      result = result.replacingOccurrences(of: "\u{0361}", with: "")
      // Remove contextual hyphens between phoneme characters
      result = result.replacingOccurrences(of: "(?<=\\S)-(?=\\S)", with: "",
                                           options: .regularExpression)
      // Strip any remaining combining tilde (U+0303) not consumed by nasal vowel mapping
      result = result.replacingOccurrences(of: "\u{0303}", with: "")
      result = result.replacingOccurrences(of: "^", with: "")
    case .enGB:
      for (old, new) in Constants.E2M {
        result = result.replacingOccurrences(of: old, with: new)
      }
      result = result.replacingOccurrences(of: "e^ə", with: "ɛː")
      result = result.replacingOccurrences(of: "iə", with: "ɪə")
      result = result.replacingOccurrences(of: "ə^ʊ", with: "Q")
      result = result.replacingOccurrences(of: "o", with: "ɔ")
      result = result.replacingOccurrences(of: "^", with: "")
    default:
      // enUS (and .none)
      for (old, new) in Constants.E2M {
        result = result.replacingOccurrences(of: old, with: new)
      }
      result = result.replacingOccurrences(of: "o^ʊ", with: "O")
      result = result.replacingOccurrences(of: "ɜːɹ", with: "ɜɹ")
      result = result.replacingOccurrences(of: "ɜː", with: "ɜɹ")
      result = result.replacingOccurrences(of: "ɪə", with: "iə")
      result = result.replacingOccurrences(of: "ː", with: "")
      result = result.replacingOccurrences(of: "o", with: "ɔ")
      result = result.replacingOccurrences(of: "^", with: "")
    }

    return result
  }

  // Find the data bundle that is inside the framework
  private func findDataBundlePath() -> String? {
    if let frameworkBundle = Bundle(identifier: "com.kokoro.espeakng"),
       let dataBundleURL = frameworkBundle.url(forResource: "espeak-ng-data", withExtension: "bundle")
    {
      return dataBundleURL.path
    }
    return nil
  }

  private enum Constants {
    static let successAudioSampleRate = 22050

    // Full English substitution table: converts eSpeak NG's English-quirk phoneme notation
    // to Kokoro's expected IPA format. Contains English-specific mappings (e->A, r->ɹ, etc.)
    // that must NOT be applied to non-English languages.
    static let E2M: [(String, String)] = [
      ("ʔˌn\u{0329}", "tn"), ("ʔn\u{0329}", "tn"), ("ʔn", "tn"), ("ʔ", "t"),
      ("a^ɪ", "I"), ("a^ʊ", "W"),
      ("d^ʒ", "ʤ"),
      ("e^ɪ", "A"), ("e", "A"),
      ("t^ʃ", "ʧ"),
      ("ɔ^ɪ", "Y"),
      ("ə^l", "ᵊl"),
      ("ʲo", "jo"), ("ʲə", "jə"), ("ʲ", ""),
      ("ɚ", "əɹ"),
      ("r", "ɹ"),
      ("x", "k"), ("ç", "k"),
      ("ɐ", "ə"),
      ("ɬ", "l"),
      ("\u{0303}", ""),
    ].sorted(by: { $0.0.count > $1.0.count })

    // Safe cross-language substitutions: only the tie-marker diphthong/affricate cleanups
    // that are valid IPA notation across all languages. Does NOT include English-specific
    // mappings like e->A, r->ɹ, x->k, ç->k that would corrupt non-English phonemes.
    static let E2M_MULTI: [(String, String)] = [
      ("a^ɪ", "I"), ("a^ʊ", "W"),
      ("d^ʒ", "ʤ"),
      ("e^ɪ", "A"),
      ("t^ʃ", "ʧ"),
      ("ɔ^ɪ", "Y"),
      ("ə^l", "ᵊl"),
      ("ʲo", "jo"), ("ʲə", "jə"), ("ʲ", ""),
    ].sorted(by: { $0.0.count > $1.0.count })
  }
}
