#!/usr/bin/env swift
// Rewrites String Catalogs (.xcstrings) exactly the way Xcode does: key order, spacing, no trailing newline.
// Run it after editing a catalog by hand so Xcode does not reformat the whole file on the next build.
// Usage: scripts/format-xcstrings.swift check|write [files...]   (default: every catalog in Packages)

import Foundation

func quote(_ s: String) -> String {
    var out = "\""
    for scalar in s.unicodeScalars {
        switch scalar {
        case "\"": out += "\\\""
        case "\\": out += "\\\\"
        case "\n": out += "\\n"
        case "\r": out += "\\r"
        case "\t": out += "\\t"
        case _ where scalar.value < 0x20: out += String(format: "\\u%04x", scalar.value)
        default: out.unicodeScalars.append(scalar)
        }
    }
    return out + "\""
}

func dump(_ value: Any, _ indent: Int) -> String {
    let pad = String(repeating: "  ", count: indent)
    let inner = String(repeating: "  ", count: indent + 1)
    switch value {
    case let dict as [String: Any]:
        if dict.isEmpty {
            return "{\n\n\(pad)}"
        }
        let keys = dict.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        return "{\n" + keys.map { "\(inner)\(quote($0)) : \(dump(dict[$0]!, indent + 1))" }.joined(separator: ",\n") + "\n\(pad)}"
    case let array as [Any]:
        if array.isEmpty {
            return "[\n\n\(pad)]"
        }
        return "[\n" + array.map { inner + dump($0, indent + 1) }.joined(separator: ",\n") + "\n\(pad)]"
    case let string as String:
        return quote(string)
    case let number as NSNumber:
        if CFGetTypeID(number) == CFBooleanGetTypeID() {
            return number.boolValue ? "true" : "false"
        }
        return number.stringValue
    default:
        fatalError("unexpected \(value)")
    }
}

let args = CommandLine.arguments
let mode = args.count > 1 ? args[1] : "write"
var paths = Array(args.dropFirst(2))
if paths.isEmpty {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Packages")
    let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)!
    paths = walker.compactMap { ($0 as? URL)?.path }.filter { $0.hasSuffix(".xcstrings") && !$0.contains("/.build/") }.sorted()
}

var differs = false
for path in paths {
    let text = try! String(contentsOfFile: path, encoding: .utf8)
    let object = try! JSONSerialization.jsonObject(with: Data(text.utf8))
    let out = dump(object, 0) // Xcode writes no trailing newline
    if mode == "check" {
        if out != text {
            differs = true; print("needs formatting: " + path)
        }
    } else if out != text {
        try! out.write(toFile: path, atomically: true, encoding: .utf8)
        print("formatted " + path)
    }
}

if differs {
    exit(1)
}
