#!/usr/bin/env swift

import AppKit
import GameController
import CoreGraphics

// MARK: - Binding Configuration

let configPath = NSString("~/.config/codecontroller.json").expandingTildeInPath

enum BindingType: String, Codable {
    case key, tap, mouse, leftClick, rightClick, cycleWindows
}

struct Binding: Codable {
    let type: BindingType
    var key: String?          // keyboard key name (for "key" and "tap")
    var modifiers: [String]?  // "command"/"cmd", "shift", "option"/"alt", "control"/"ctrl"
    var button: Int?          // mouse button number (for "mouse")
}

struct Settings: Codable {
    var logging: Bool?
}

struct Config: Codable {
    var settings: Settings?
    var bindings: [String: Binding]
}

let defaultConfigJSON = """
{
  "settings": {
    "logging": true
  },
  "bindings": {
    "a":              { "key":    "return",      "type": "key"          },
    "b":              { "key":    "escape",      "type": "key"          },
    "x":              { "key":    "backspace",   "type": "key"          },
    "y":              { "key":    "tab",         "type": "key"          },
    "back":           { "key":    "o",           "type": "tap",           "modifiers": ["control"] },
    "menu":           { "key":    "/",           "type": "key"          },
    "dpad_up":        { "key":    "up",          "type": "key"          },
    "dpad_down":      { "key":    "down",        "type": "key"          },
    "dpad_left":      { "key":    "left",        "type": "key"          },
    "dpad_right":     { "key":    "right",       "type": "key"          },
    "ls":             {                          "type": "leftClick"    },
    "rs":             {                          "type": "rightClick"   },

    "lt+a":           { "key":    "space",       "type": "key"          },
    "lt+y":           { "key":    "tab",         "type": "tap",           "modifiers": ["shift"] },
    "lt+back":        { "key":    "e",           "type": "tap",           "modifiers": ["control"] },
    "lt+dpad_up":     {                          "type": "cycleWindows" },
    "lt+dpad_down":   {                          "type": "cycleWindows" },
    "lt+dpad_left":   { "key":    "[",           "type": "tap",           "modifiers": ["command", "shift"] },
    "lt+dpad_right":  { "key":    "]",           "type": "tap",           "modifiers": ["command", "shift"] },

    "lb+b":           { "key":    "w",           "type": "tap",           "modifiers": ["command"] },
    "lb+y":           { "key":    "t",           "type": "tap",           "modifiers": ["command"] },
    "lb+back":        { "key":    "b",           "type": "tap",           "modifiers": ["control"] }
  }
}
"""

// Key name -> macOS virtual key code
let keyNameToCode: [String: CGKeyCode] = [
    // Letters
    "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
    "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
    "o": 31, "u": 32, "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46,
    // Numbers
    "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22, "7": 26, "8": 28, "9": 25, "0": 29,
    // Special
    "return": 36, "tab": 48, "space": 49, "backspace": 51, "escape": 53, "delete": 117,
    // Arrow keys
    "up": 126, "down": 125, "left": 123, "right": 124,
    // Function keys
    "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97,
    "f7": 98, "f8": 100, "f9": 101, "f10": 109, "f11": 103, "f12": 111,
    // Punctuation
    "/": 44, "slash": 44, "[": 33, "]": 30, "-": 27, "minus": 27,
    "=": 24, "equal": 24, ";": 41, "semicolon": 41,
    "'": 39, "quote": 39, ",": 43, "comma": 43,
    ".": 47, "period": 47, "\\": 42, "backslash": 42, "`": 50, "grave": 50,
    // Navigation
    "home": 115, "end": 119, "pageup": 116, "pagedown": 121,
]

func resolveKeyCode(_ name: String) -> CGKeyCode? {
    keyNameToCode[name.lowercased()]
}

func resolveModifiers(_ names: [String]) -> CGEventFlags {
    var flags: CGEventFlags = []
    for name in names {
        switch name.lowercased() {
        case "command", "cmd": flags.insert(.maskCommand)
        case "shift":          flags.insert(.maskShift)
        case "option", "alt":  flags.insert(.maskAlternate)
        case "control", "ctrl": flags.insert(.maskControl)
        default: break
        }
    }
    return flags
}

func describeBinding(_ b: Binding) -> String {
    switch b.type {
    case .key, .tap:
        let mods = (b.modifiers ?? []).map { $0.capitalized }
        let key = (b.key ?? "?").capitalized
        return (mods + [key]).joined(separator: "+")
    case .mouse:        return "Mouse \(b.button ?? 0)"
    case .leftClick:    return "Left Click"
    case .rightClick:   return "Right Click"
    case .cycleWindows: return "Cycle Windows"
    }
}

// Load config from file, or write defaults
func loadConfig() -> Config {
    let configDir = (configPath as NSString).deletingLastPathComponent

    if FileManager.default.fileExists(atPath: configPath) {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
            // Try new nested format first
            if var config = try? JSONDecoder().decode(Config.self, from: data) {
                // Migrate l3/r3 -> ls/rs
                if let v = config.bindings.removeValue(forKey: "l3") { config.bindings["ls"] = config.bindings["ls"] ?? v }
                if let v = config.bindings.removeValue(forKey: "r3") { config.bindings["rs"] = config.bindings["rs"] ?? v }
                print("Loaded \(config.bindings.count) bindings from \(configPath)")
                return config
            }
            // Fall back to old flat format (bindings only, no settings)
            var flat = try JSONDecoder().decode([String: Binding].self, from: data)
            if let v = flat.removeValue(forKey: "l3") { flat["ls"] = flat["ls"] ?? v }
            if let v = flat.removeValue(forKey: "r3") { flat["rs"] = flat["rs"] ?? v }
            print("Loaded \(flat.count) bindings from \(configPath) (legacy format)")
            return Config(settings: nil, bindings: flat)
        } catch {
            print("ERROR: Failed to parse \(configPath): \(error)")
            print("Using default bindings")
        }
    } else {
        do {
            try FileManager.default.createDirectory(atPath: configDir, withIntermediateDirectories: true)
            try defaultConfigJSON.write(toFile: configPath, atomically: true, encoding: .utf8)
            print("Wrote default config to \(configPath)")
        } catch {
            print("WARNING: Could not write default config: \(error)")
        }
    }

    return try! JSONDecoder().decode(Config.self, from: defaultConfigJSON.data(using: .utf8)!)
}

let validButtonNames = Set(["a", "b", "x", "y", "rt", "rb", "ls", "rs", "dpad_up", "dpad_down", "dpad_left", "dpad_right", "back", "menu"])
let validPrefixes = ["lt+", "lb+"]

func validateBindings(_ config: [String: Binding]) -> [String] {
    var warnings: [String] = []
    for (name, binding) in config.sorted(by: { $0.key < $1.key }) {
        // Validate binding key name
        var baseName = name
        for prefix in validPrefixes {
            if name.hasPrefix(prefix) { baseName = String(name.dropFirst(prefix.count)); break }
        }
        if !validButtonNames.contains(baseName) {
            warnings.append("\"\(name)\": unknown button name \"\(baseName)\"")
        }

        // Validate key/tap have a key
        if binding.type == .key || binding.type == .tap {
            if let key = binding.key {
                if resolveKeyCode(key) == nil {
                    warnings.append("\"\(name)\": unknown key name \"\(key)\"")
                }
            } else {
                warnings.append("\"\(name)\": type \"\(binding.type.rawValue)\" requires a \"key\" field")
            }
        }

        // Validate mouse button number
        if binding.type == .mouse {
            if let btn = binding.button {
                if btn < 0 {
                    warnings.append("\"\(name)\": negative mouse button number \(btn)")
                }
            } else {
                warnings.append("\"\(name)\": type \"mouse\" requires a \"button\" field")
            }
        }

        // Validate modifier names
        for mod in binding.modifiers ?? [] {
            let valid = ["command", "cmd", "shift", "option", "alt", "control", "ctrl"]
            if !valid.contains(mod.lowercased()) {
                warnings.append("\"\(name)\": unknown modifier \"\(mod)\"")
            }
        }
    }
    return warnings
}

func showConfigWarnings(_ warnings: [String]) {
    guard !warnings.isEmpty else { return }
    let message = warnings.joined(separator: "\n")
    print("Config warnings:\n\(message)")
    DispatchQueue.main.async {
        let alert = NSAlert()
        alert.messageText = "Config Warnings"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

var config = loadConfig()
var bindings = config.bindings
var loggingEnabled = config.settings?.logging ?? true
showConfigWarnings(validateBindings(bindings))

// MARK: - Constants

// Mouse cursor (left stick)
let mouseDeadzone: Float = 0.10
let mouseSpeed: Double = 20.0
let mouseAccel: Double = 0.35
let mouseDecay: Double = 0.7

// Scroll (right stick)
let scrollDeadzone: Float = 0.02
let scrollSpeed: Float = 30.0
let scrollAccel: Float = 0.15
let scrollDecay: Float = 0.92
let scrollFlat: Float = 1.0
let scrollCurve: Float = 5.5

// Universal mouse button fallback: every button combo gets a sequential number (10-51)
let canonicalOrder = ["a", "b", "x", "y", "rt", "rb", "ls", "rs", "dpad_up", "dpad_down", "dpad_left", "dpad_right", "back", "menu"]

func fallbackMouseButton(for name: String) -> Int {
    let idx = canonicalOrder.firstIndex(of: name) ?? 0
    return 10 + idx
}

// Modifier flags attached to fallback mouse events to distinguish layers
func fallbackModifiers(ltHeld: Bool, lbHeld: Bool) -> CGEventFlags {
    if lbHeld { return .maskControl }
    if ltHeld { return .maskAlternate }
    return []
}

// MARK: - State

var buttonStates: [String: Bool] = [:]
var activeBindingObjects: [String: Binding] = [:]  // button name -> binding that was activated
var activeMouseModifiers: [String: CGEventFlags] = [:]  // button name -> modifier flags for fallback mouse
var scrollVelocityX: Float = 0
var scrollVelocityY: Float = 0
var mouseVelocityX: Double = 0
var mouseVelocityY: Double = 0
var mouseDown = false
var rightMouseDown = false

// MARK: - Event Simulation

let eventSource = CGEventSource(stateID: .privateState)

func pressKey(_ keyCode: CGKeyCode, down: Bool, modifiers: CGEventFlags = []) {
    let event = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: down)
    event?.flags = modifiers
    event?.post(tap: .cgSessionEventTap)
}

// Posts explicit modifier key-down/up events around the main key.
// Required for system shortcuts (e.g. Cmd+Shift+[) that don't register from just setting CGEvent flags.
func tapKey(_ keyCode: CGKeyCode, modifiers: CGEventFlags = []) {
    let modifierKeys: [(CGEventFlags, CGKeyCode)] = [
        (.maskCommand, 55), (.maskShift, 56), (.maskAlternate, 58), (.maskControl, 59)
    ]
    let activeModifiers = modifierKeys.filter { modifiers.contains($0.0) }
    for (flag, key) in activeModifiers {
        let down = CGEvent(keyboardEventSource: eventSource, virtualKey: key, keyDown: true)
        down?.flags = flag
        down?.post(tap: .cgSessionEventTap)
    }
    pressKey(keyCode, down: true, modifiers: modifiers)
    pressKey(keyCode, down: false, modifiers: modifiers)
    for (_, key) in activeModifiers.reversed() {
        let up = CGEvent(keyboardEventSource: eventSource, virtualKey: key, keyDown: false)
        up?.flags = []
        up?.post(tap: .cgSessionEventTap)
    }
}

func pressMouseButton(_ button: CGMouseButton, down: Bool, modifiers: CGEventFlags = []) {
    let location = CGEvent(source: nil)?.location ?? .zero
    let eventType: CGEventType = down ? .otherMouseDown : .otherMouseUp
    if let event = CGEvent(mouseEventSource: eventSource, mouseType: eventType, mouseCursorPosition: location, mouseButton: button) {
        event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(button.rawValue))
        if !modifiers.isEmpty { event.flags = modifiers }
        event.post(tap: .cgSessionEventTap)
    }
}

func mouseClick(down: Bool) {
    guard mouseDown != down else { return }
    mouseDown = down
    let location = CGEvent(source: nil)?.location ?? .zero
    let eventType: CGEventType = down ? .leftMouseDown : .leftMouseUp
    if let event = CGEvent(mouseEventSource: nil, mouseType: eventType, mouseCursorPosition: location, mouseButton: .left) {
        event.post(tap: .cgSessionEventTap)
    }
}

func rightClick(down: Bool) {
    guard rightMouseDown != down else { return }
    rightMouseDown = down
    let location = CGEvent(source: nil)?.location ?? .zero
    let eventType: CGEventType = down ? .rightMouseDown : .rightMouseUp
    if let event = CGEvent(mouseEventSource: nil, mouseType: eventType, mouseCursorPosition: location, mouseButton: .right) {
        event.post(tap: .cgSessionEventTap)
    }
}

func moveMouse(dx: Double, dy: Double) {
    let loc = CGEvent(source: nil)?.location ?? .zero
    if let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: loc.x + dx, y: loc.y + dy), mouseButton: .left) {
        event.post(tap: .cgSessionEventTap)
    }
}

func scroll(dx: Int32, dy: Int32) {
    if let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: dy, wheel2: dx, wheel3: 0) {
        event.post(tap: .cgSessionEventTap)
    }
}

// MARK: - Window Cycling

func cycleWindows() {
    guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return }
    guard let frontPid = windowList.first(where: { ($0[kCGWindowLayer as String] as? Int) == 0 })?[kCGWindowOwnerPID as String] as? pid_t else { return }

    let app = AXUIElementCreateApplication(frontPid)
    var windowsRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef) == .success,
          let axWindows = windowsRef as? [AXUIElement], axWindows.count > 1 else { return }

    let target = axWindows.last!
    AXUIElementPerformAction(target, kAXRaiseAction as CFString)
    AXUIElementSetAttributeValue(app, kAXMainWindowAttribute as CFString, target)
    AXUIElementSetAttributeValue(app, kAXFrontmostAttribute as CFString, true as CFTypeRef)
}

// MARK: - Binding Dispatch

func executeBinding(_ binding: Binding, down: Bool, mouseFlags: CGEventFlags = []) {
    switch binding.type {
    case .key:
        guard let name = binding.key, let code = resolveKeyCode(name) else { return }
        pressKey(code, down: down, modifiers: resolveModifiers(binding.modifiers ?? []))
    case .tap:
        guard down, let name = binding.key, let code = resolveKeyCode(name) else { return }
        tapKey(code, modifiers: resolveModifiers(binding.modifiers ?? []))
    case .mouse:
        guard let btn = binding.button, btn >= 0, btn <= 31 else { return }
        pressMouseButton(CGMouseButton(rawValue: UInt32(btn))!, down: down, modifiers: mouseFlags)
    case .leftClick:
        mouseClick(down: down)
    case .rightClick:
        rightClick(down: down)
    case .cycleWindows:
        if down { cycleWindows() }
    }
}

func handleButton(_ name: String, pressed: Bool, ltHeld: Bool, lbHeld: Bool) {
    guard buttonStates[name] != pressed else { return }
    buttonStates[name] = pressed

    if pressed {
        // Pick binding key based on active modifier layer
        let bindingKey: String
        if lbHeld {
            bindingKey = "lb+\(name)"
        } else if ltHeld {
            bindingKey = "lt+\(name)"
        } else {
            bindingKey = name
        }

        // Use config binding if present, otherwise fall back to mouse button
        let binding: Binding
        let mouseFlags: CGEventFlags
        if let b = bindings[bindingKey] {
            binding = b
            mouseFlags = []
        } else {
            let mouseBtn = fallbackMouseButton(for: name)
            binding = Binding(type: .mouse, key: nil, modifiers: nil, button: mouseBtn)
            mouseFlags = fallbackModifiers(ltHeld: ltHeld, lbHeld: lbHeld)
        }

        activeBindingObjects[name] = binding
        activeMouseModifiers[name] = mouseFlags
        executeBinding(binding, down: true, mouseFlags: mouseFlags)
        let modDesc = mouseFlags.contains(.maskControl) ? " +Ctrl" : mouseFlags.contains(.maskAlternate) ? " +Opt" : ""
        print("\(bindingKey) -> \(describeBinding(binding))\(modDesc)")
    } else {
        // Release the same binding that was activated (prevents stuck keys)
        if let binding = activeBindingObjects.removeValue(forKey: name) {
            let mouseFlags = activeMouseModifiers.removeValue(forKey: name) ?? []
            executeBinding(binding, down: false, mouseFlags: mouseFlags)
        }
    }
}

// MARK: - Polling

func pollController(_ gamepad: GCExtendedGamepad) {
    let ltHeld = gamepad.leftTrigger.value > 0.5
    let lbHeld = gamepad.leftShoulder.isPressed

    // --- Buttons (all dispatch through handleButton) ---
    handleButton("a",          pressed: gamepad.buttonA.isPressed,                    ltHeld: ltHeld, lbHeld: lbHeld)
    handleButton("b",          pressed: gamepad.buttonB.isPressed,                    ltHeld: ltHeld, lbHeld: lbHeld)
    handleButton("x",          pressed: gamepad.buttonX.isPressed,                    ltHeld: ltHeld, lbHeld: lbHeld)
    handleButton("y",          pressed: gamepad.buttonY.isPressed,                    ltHeld: ltHeld, lbHeld: lbHeld)
    handleButton("rb",         pressed: gamepad.rightShoulder.isPressed,              ltHeld: ltHeld, lbHeld: lbHeld)
    handleButton("rt",         pressed: gamepad.rightTrigger.value > 0.5,             ltHeld: ltHeld, lbHeld: lbHeld)
    handleButton("back",       pressed: gamepad.buttonOptions?.isPressed ?? false,    ltHeld: ltHeld, lbHeld: lbHeld)
    handleButton("menu",       pressed: gamepad.buttonMenu.isPressed,                 ltHeld: ltHeld, lbHeld: lbHeld)
    handleButton("ls",         pressed: gamepad.leftThumbstickButton?.isPressed ?? false,  ltHeld: ltHeld, lbHeld: lbHeld)
    handleButton("rs",         pressed: gamepad.rightThumbstickButton?.isPressed ?? false, ltHeld: ltHeld, lbHeld: lbHeld)
    handleButton("dpad_up",    pressed: gamepad.dpad.up.isPressed,                    ltHeld: ltHeld, lbHeld: lbHeld)
    handleButton("dpad_down",  pressed: gamepad.dpad.down.isPressed,                  ltHeld: ltHeld, lbHeld: lbHeld)
    handleButton("dpad_left",  pressed: gamepad.dpad.left.isPressed,                  ltHeld: ltHeld, lbHeld: lbHeld)
    handleButton("dpad_right", pressed: gamepad.dpad.right.isPressed,                 ltHeld: ltHeld, lbHeld: lbHeld)

    // --- Left stick: mouse movement with momentum ---
    let mouseX = gamepad.leftThumbstick.xAxis.value
    let mouseY = gamepad.leftThumbstick.yAxis.value

    if abs(mouseX) > mouseDeadzone || abs(mouseY) > mouseDeadzone {
        let curvedX = (mouseX > 0 ? 1.0 : -1.0) * pow(Double(abs(mouseX)), 1.5) * mouseSpeed
        let curvedY = (mouseY > 0 ? 1.0 : -1.0) * pow(Double(abs(mouseY)), 1.5) * mouseSpeed
        mouseVelocityX += (curvedX - mouseVelocityX) * mouseAccel
        mouseVelocityY += (-curvedY - mouseVelocityY) * mouseAccel
    } else {
        mouseVelocityX *= mouseDecay
        mouseVelocityY *= mouseDecay
    }

    if abs(mouseVelocityX) > 0.3 || abs(mouseVelocityY) > 0.3 {
        moveMouse(dx: mouseVelocityX, dy: mouseVelocityY)
    }

    // --- Right stick: scrolling with momentum ---
    let scrollX = gamepad.rightThumbstick.xAxis.value
    let scrollY = gamepad.rightThumbstick.yAxis.value

    if abs(scrollX) > scrollDeadzone || abs(scrollY) > scrollDeadzone {
        let curvedX = (scrollX > 0 ? 1.0 : -1.0) * pow(abs(scrollX), scrollCurve) * scrollSpeed
        let curvedY = (scrollY > 0 ? 1.0 : -1.0) * pow(abs(scrollY), scrollCurve) * scrollSpeed
        scrollVelocityX += (curvedX - scrollVelocityX) * scrollAccel
        scrollVelocityY += (curvedY - scrollVelocityY) * scrollAccel
    } else {
        scrollVelocityX *= scrollDecay
        scrollVelocityY *= scrollDecay
        if scrollVelocityX > scrollFlat { scrollVelocityX -= scrollFlat }
        else if scrollVelocityX < -scrollFlat { scrollVelocityX += scrollFlat }
        else { scrollVelocityX = 0 }
        if scrollVelocityY > scrollFlat { scrollVelocityY -= scrollFlat }
        else if scrollVelocityY < -scrollFlat { scrollVelocityY += scrollFlat }
        else { scrollVelocityY = 0 }
    }

    if abs(scrollVelocityX) > 0.5 || abs(scrollVelocityY) > 0.5 {
        scroll(dx: -Int32(scrollVelocityX), dy: Int32(scrollVelocityY))
    }
}

// MARK: - Menu Bar

class AppActions: NSObject {
    let statusItem: NSStatusItem
    let statusMenuItem: NSMenuItem

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusMenuItem = NSMenuItem(title: "No controller", action: nil, keyEquivalent: "")
        super.init()

        if let iconPath = Bundle.main.path(forResource: "icon", ofType: "png"),
           let icon = NSImage(contentsOfFile: iconPath) {
            icon.isTemplate = true
            icon.size = NSSize(width: 18, height: 18)
            statusItem.button?.image = icon
        } else {
            statusItem.button?.title = "\u{1F3AE}"
        }

        let menu = NSMenu()
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Show README", action: #selector(showReadme), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Edit Bindings...", action: #selector(editBindings), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Reload Config", action: #selector(reloadConfig), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items where item.action != nil {
            item.target = self
        }
        statusItem.menu = menu
    }

    func updateStatus(controllers: [GCController]) {
        if let c = controllers.first {
            statusMenuItem.title = "\(c.vendorName ?? "Controller") Connected"
        } else {
            statusMenuItem.title = "No controller"
        }
    }

    @objc func showReadme() {
        guard let readmePath = Bundle.main.path(forResource: "README", ofType: "md"),
              let md = try? String(contentsOfFile: readmePath, encoding: .utf8),
              let markedPath = Bundle.main.path(forResource: "marked.min", ofType: "js"),
              let markedJS = try? String(contentsOfFile: markedPath, encoding: .utf8),
              let templatePath = Bundle.main.path(forResource: "readme_template", ofType: "html"),
              let template = try? String(contentsOfFile: templatePath, encoding: .utf8) else { return }
        let page = template
            .replacingOccurrences(of: "{{MARKED_JS}}", with: markedJS)
            .replacingOccurrences(of: "{{MARKDOWN_BASE64}}", with: Data(md.utf8).base64EncodedString())
        let tmpPath = NSTemporaryDirectory() + "codecontroller_readme.html"
        try? page.write(toFile: tmpPath, atomically: true, encoding: .utf8)
        NSWorkspace.shared.open(URL(fileURLWithPath: tmpPath))
    }

    @objc func editBindings() {
        NSWorkspace.shared.open(URL(fileURLWithPath: configPath))
    }

    @objc func reloadConfig() {
        config = loadConfig()
        bindings = config.bindings
        loggingEnabled = config.settings?.logging ?? true
        print("Config reloaded (\(bindings.count) bindings)")
        showConfigWarnings(validateBindings(bindings))
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Main

if loggingEnabled {
    let logPath = NSString("~/Library/Logs/CodeController.log").expandingTildeInPath
    freopen(logPath, "a", stdout)
    freopen(logPath, "a", stderr)
    setbuf(stdout, nil)
    print("CodeController started")
}

let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
if !AXIsProcessTrustedWithOptions(opts) {
    print("Accessibility permission not granted — prompting user")
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let appActions = AppActions()

NotificationCenter.default.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { _ in
    GCController.shouldMonitorBackgroundEvents = true
}
GCController.startWirelessControllerDiscovery {}

var lastControllerCount = 0
var noControllerTicks = 0

Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { _ in
    let controllers = GCController.controllers()

    if controllers.count != lastControllerCount {
        lastControllerCount = controllers.count
        noControllerTicks = 0
        appActions.updateStatus(controllers: controllers)
        print("Controllers: \(controllers.count)")
        for c in controllers {
            print("  - \(c.vendorName ?? "Unknown") (\(c.productCategory))")
        }
    }

    if controllers.isEmpty {
        noControllerTicks += 1
        if noControllerTicks == 300 {
            print("No controllers - retrying discovery...")
            GCController.startWirelessControllerDiscovery {}
            noControllerTicks = 0
        }
    } else {
        noControllerTicks = 0
    }

    for controller in controllers {
        if let gamepad = controller.extendedGamepad {
            pollController(gamepad)
        }
    }
}

app.run()
