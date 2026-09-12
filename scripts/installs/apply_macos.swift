// Targeted current-user restoration. No whole-domain imports or plist symlinks.
import Foundation
import Carbon

struct Failure: Error, CustomStringConvertible { let description: String }
let fm = FileManager.default
var args = Array(CommandLine.arguments.dropFirst())
func option(_ name: String) -> String? {
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
    let value = args[i + 1]; args.removeSubrange(i...i + 1); return value
}
let fixture = option("--fixture")
let dryRun = args.contains("--dry-run")
args.removeAll { $0 == "--dry-run" }
guard args.count == 1 else { fatalError("Usage: apply_macos.swift preferences.json [--dry-run] [--fixture DIRECTORY]") }
let config = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: args[0]))) as! [String: Any]
let userHome = ProcessInfo.processInfo.environment["HOME"]!
let backupRoot = fixture.map { $0 + "/backups" } ?? userHome + "/Library/Application Support/workspace/macos-backups"
let backupDir = backupRoot + "/" + UUID().uuidString
var changeCount = 0
var manualCount = 0
func manual(_ message: String) { manualCount += 1; print("MANUAL: " + message) }
func domainID(_ domain: String) -> CFString { domain == "NSGlobalDomain" ? kCFPreferencesAnyApplication : domain as CFString }
func fixtureFile(_ domain: String) -> URL { URL(fileURLWithPath: fixture! + "/" + domain + ".plist") }
func fixtureDomain(_ domain: String) throws -> [String: Any] {
    let file = fixtureFile(domain)
    if !fm.fileExists(atPath: file.path) { return [:] }
    return try PropertyListSerialization.propertyList(from: Data(contentsOf: file), format: nil) as! [String: Any]
}
func read(_ domain: String, _ key: String) throws -> Any? {
    if fixture != nil { return try fixtureDomain(domain)[key] }
    return CFPreferencesCopyValue(key as CFString, domainID(domain), kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
}
func equal(_ a: Any?, _ b: Any) -> Bool { guard let a = a else { return false }; return NSDictionary(dictionary: ["v": a]).isEqual(to: ["v": b]) }
func backup(_ name: String, _ old: Any?) throws {
    if dryRun { return }
    try fm.createDirectory(atPath: backupDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    // A private local snapshot of only the changed key, never an entire domain.
    let record: [String: Any] = old.map { ["present": true, "value": $0] } ?? ["present": false]
    let bytes = try PropertyListSerialization.data(fromPropertyList: record, format: .xml, options: 0)
    let dest = backupDir + "/" + name + ".plist"
    try bytes.write(to: URL(fileURLWithPath: dest), options: .atomic)
    try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: dest)
}
func write(_ domain: String, _ key: String, _ value: Any) throws {
    let old = try read(domain, key)
    if equal(old, value) { return }
    changeCount += 1
    print((dryRun ? "WOULD SET " : "SET ") + domain + ":" + key)
    if dryRun { return }
    try backup(domain + "--" + key, old)
    if fixture != nil {
        var all = try fixtureDomain(domain); all[key] = value
        let bytes = try PropertyListSerialization.data(fromPropertyList: all, format: .xml, options: 0)
        try bytes.write(to: fixtureFile(domain), options: .atomic)
    } else {
        CFPreferencesSetValue(key as CFString, value as CFPropertyList, domainID(domain), kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        guard CFPreferencesSynchronize(domainID(domain), kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else { throw Failure(description: "Could not synchronize " + domain) }
        guard equal(try read(domain, key), value) else { throw Failure(description: "Readback failed for " + domain + ":" + key) }
    }
}
func merge(_ current: [String: Any], _ desired: [String: Any]) -> [String: Any] {
    var result = current
    for (key, value) in desired {
        if let d = value as? [String: Any], let c = result[key] as? [String: Any] { result[key] = merge(c, d) }
        else { result[key] = value }
    }
    return result
}
func expanded(_ path: String) -> String { path.hasPrefix("~/") ? userHome + String(path.dropFirst()) : path }
func exists(_ path: String) -> Bool { fm.fileExists(atPath: fixture.map { $0 + "/files" + path } ?? path) }
func appPath(_ app: [String: String]) -> String? {
    let path = app["path"]!
    if exists(path) { return path }
    // Resolve only the supplied stable ID, never enumerate user application data.
    if fixture == nil, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app["bundle_id"]!) { return url.path }
    return nil
}
func tilePath(_ tile: [String: Any]) -> String? {
    guard let data = tile["tile-data"] as? [String: Any], let file = data["file-data"] as? [String: Any], let raw = file["_CFURLString"] as? String else { return nil }
    return raw.hasPrefix("file:") ? URL(string: raw)?.path : raw
}
func restoreDock(_ key: String, _ desired: [[String: Any]]) throws {
    let old = try read("com.apple.dock", key) as? [[String: Any]] ?? []
    var remaining = old
    var ordered: [[String: Any]] = []
    for item in desired {
        let path = item["path"] as! String
        let bundle = item["bundle_id"] as? String
        let matches: ([String: Any]) -> Bool = { tile in
            let data = tile["tile-data"] as? [String: Any] ?? [:]
            return tilePath(tile) == path || (bundle != nil && data["bundle-identifier"] as? String == bundle)
        }
        var tile = remaining.first(where: matches) ?? ["tile-type": bundle == nil ? "directory-tile" : "file-tile", "tile-data": ["file-data": ["_CFURLString": URL(fileURLWithPath: path).absoluteString, "_CFURLStringType": 15], "file-label": URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent]]
        var data = tile["tile-data"] as! [String: Any]
        if let bundle = bundle { data["bundle-identifier"] = bundle }
        for k in ["arrangement", "displayas", "showas"] { if let v = item[k] { data[k] = v } }
        tile["tile-data"] = data
        ordered.append(tile); remaining.removeAll(where: matches)
    }
    // Managed pins lead in captured order; retain all unrelated existing pins afterwards.
    try write("com.apple.dock", key, ordered + remaining)
}
func tisProperty(_ source: TISInputSource, _ key: CFString) -> AnyObject? {
    guard let ptr = TISGetInputSourceProperty(source, key) else { return nil }
    return Unmanaged<AnyObject>.fromOpaque(ptr).takeUnretainedValue()
}
func sources(_ id: String) -> [TISInputSource] {
    guard let list = TISCreateInputSourceList([kTISPropertyInputSourceID as String: id] as CFDictionary, true) else { return [] }
    return list.takeRetainedValue() as! [TISInputSource]
}
func restoreInputs() throws {
    let input = config["input_sources"] as! [String: Any]
    let ids = input["enabled"] as! [String]
    let selected = input["selected"] as! String
    if fixture != nil {
        var state = try read("fixture-input", "state") as? [String: Any] ?? [:]
        let enabled = state["enabled"] as? [String] ?? []
        state["enabled"] = enabled + ids.filter { !enabled.contains($0) }; state["selected"] = selected
        try write("fixture-input", "state", state); return
    }
    for id in ids {
        guard let source = sources(id).first else { manual("Input source unavailable: " + id + ". Add it in System Settings > Keyboard > Text Input > Edit."); continue }
        if tisProperty(source, kTISPropertyInputSourceIsEnabled) as? Bool == true { continue }
        if dryRun { print("WOULD ENABLE " + id); continue }
        try backup("input--" + id, ["enabled": false])
        if TISEnableInputSource(source) != noErr || tisProperty(source, kTISPropertyInputSourceIsEnabled) as? Bool != true { manual("Enable " + id + " in Text Input settings.") }
    }
    guard let currentRef = TISCopyCurrentKeyboardInputSource() else {
        manual("Input-source API unavailable in this session. Add ABC in Text Input settings, then select ABC."); return
    }
    let current = currentRef.takeRetainedValue()
    let currentID = tisProperty(current, kTISPropertyInputSourceID) as? String ?? ""
    if currentID != selected, let source = sources(selected).first {
        if dryRun { print("WOULD SELECT " + selected); return }
        try backup("input--selected", currentID)
        if TISSelectInputSource(source) != noErr { manual("Select ABC from the input menu.") }
        else if let now = TISCopyCurrentKeyboardInputSource(), tisProperty(now.takeRetainedValue(), kTISPropertyInputSourceID) as? String != selected { manual("ABC selection did not take effect; select ABC from the input menu.") }
    }
}
import AppKit
for (domain, prefs) in config["preferences"] as! [String: [String: Any]] {
    for (key, value) in prefs { try write(domain, key, value) }
}
for (domain, desired) in config["menu_shortcuts"] as! [String: [String: Any]] {
    let current = try read(domain, "NSUserKeyEquivalents") as? [String: Any] ?? [:]
    try write(domain, "NSUserKeyEquivalents", merge(current, desired))
}
// These IDs are private macOS preference conventions, verified only on captured major version.
let sourceMajor = Int((config["captured_macos"] as! String).split(separator: ".")[0])!
if fixture != nil || ProcessInfo.processInfo.operatingSystemVersion.majorVersion == sourceMajor {
    let current = try read("com.apple.symbolichotkeys", "AppleSymbolicHotKeys") as? [String: Any] ?? [:]
    try write("com.apple.symbolichotkeys", "AppleSymbolicHotKeys", merge(current, config["symbolic_hotkeys"] as! [String: Any]))
} else { manual("System shortcut IDs were captured on macOS \(sourceMajor). Restore them using the guide; automatic shortcut writes skipped on this major version.") }
var apps: [[String: Any]] = []
for app in config["dock_apps"] as! [[String: String]] {
    if let path = appPath(app) { apps.append(["path": path, "bundle_id": app["bundle_id"]!]) }
    else { manual("Missing Dock app: " + app["path"]! + ". Install it, then rerun setup_macos.sh.") }
}
if !apps.isEmpty { try restoreDock("persistent-apps", apps) }
var folders: [[String: Any]] = []
for var folder in config["dock_folders"] as! [[String: Any]] {
    let path = expanded(folder["path"] as! String)
    if exists(path) { folder["path"] = path; folders.append(folder) }
    else { manual("Missing Dock folder: " + (folder["path"] as! String) + ". Create it, then rerun setup_macos.sh.") }
}
if !folders.isEmpty { try restoreDock("persistent-others", folders) }
try restoreInputs()
manual("Check Dictation's Control modifier shortcut and restore Finder sidebar favorites: docs/install/macos-preferences.md.")
print("\(dryRun ? "Planned" : "Applied") \(changeCount) preference changes; \(manualCount) manual notices.")
if fm.fileExists(atPath: backupDir) { print("Private scoped backup: " + backupDir) }
