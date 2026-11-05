import Foundation

/// Repairs tag text that was written in another 8-bit encoding but read as Latin-1.
///
/// Many Russian MP3s carry Windows-1251 bytes in ID3 frames flagged as ISO-8859-1 (and ID3v1 has no
/// encoding at all). AVFoundation decodes them as Latin-1 and exposes no raw bytes, so "Тимати"
/// arrives as "Òèìàòè". The repair maps the string back to its bytes and re-decodes them, but only
/// when the result is unambiguous:
///
/// - Every scalar must fit in one byte (Latin-1, or a Windows-1252 punctuation mark). Any other
///   character means the text is real Unicode, so correct Cyrillic is never touched.
/// - Bytes that form valid multi-byte UTF-8 are decoded as UTF-8 ("Ð¢Ð¸Ð¼Ð°Ñ‚Ð¸").
/// - Otherwise the Windows-1251 reading must have no word mixing Cyrillic with other letters and at
///   least one Cyrillic word of two or more letters. Genuine Latin-1 text keeps its accented letters
///   inside Latin words ("Beyoncé" would read "Beyoncщ"), so it never qualifies.
///
/// The cost of being conservative: a mojibake title that is a single Cyrillic letter ("ß" for "Я")
/// stays as it is, since it can't be told apart from a one-letter Latin-1 word ("Ø").
enum TagTextRepair {
    /// The repaired text, or `text` itself when it doesn't look mislabelled.
    static func repair(_ text: String) -> String {
        repaired(text) ?? text
    }

    /// The repaired text, or `nil` when `text` should stay as it is.
    static func repaired(_ text: String) -> String? {
        guard let bytes = singleByteEncoding(of: text), bytes.contains(where: { $0 >= 0x80 }) else {
            return nil
        }
        if let utf8 = String(validating: bytes, as: UTF8.self) {
            return isClean(utf8) ? utf8 : nil
        }
        guard let cyrillic = String(bytes: bytes, encoding: .windowsCP1251),
              isClean(cyrillic), readsAsCyrillic(cyrillic)
        else {
            return nil
        }
        return cyrillic
    }

    /// Windows-1252 marks in 0x80–0x9F, for text decoded as Windows-1252 rather than strict Latin-1.
    private static let windows1252Bytes: [Unicode.Scalar: UInt8] = {
        var table: [Unicode.Scalar: UInt8] = [:]
        for byte in UInt8(0x80) ... 0x9F {
            if let scalar = String(bytes: [byte], encoding: .windowsCP1252)?.unicodeScalars.first, scalar.value > 0xFF {
                table[scalar] = byte
            }
        }
        return table
    }()

    private static func singleByteEncoding(of text: String) -> [UInt8]? {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(text.unicodeScalars.count)
        for scalar in text.unicodeScalars {
            if scalar.value <= 0xFF {
                bytes.append(UInt8(scalar.value))
            } else if let byte = windows1252Bytes[scalar] {
                bytes.append(byte)
            } else {
                return nil
            }
        }
        return bytes
    }

    /// No control characters other than whitespace: they mean the bytes were not meant for this encoding.
    private static func isClean(_ text: String) -> Bool {
        !text.unicodeScalars.contains { $0.properties.generalCategory == .control && !$0.properties.isWhitespace }
    }

    private static func readsAsCyrillic(_ text: String) -> Bool {
        var hasCyrillicWord = false
        var cyrillic = 0
        var other = 0

        func endWord() -> Bool {
            defer { (cyrillic, other) = (0, 0) }
            if cyrillic > 0, other > 0 {
                return false
            }
            hasCyrillicWord = hasCyrillicWord || cyrillic >= 2
            return true
        }

        for scalar in text.unicodeScalars {
            if scalar.properties.isAlphabetic {
                if (0x0400 ... 0x04FF).contains(scalar.value) {
                    cyrillic += 1
                } else {
                    other += 1
                }
            } else if !endWord() {
                return false
            }
        }
        return endWord() && hasCyrillicWord
    }
}
