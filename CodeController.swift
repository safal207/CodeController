#!/usr/bin/env swift

import AppKit
import GameController
import CoreGraphics

// MARK: - Binding Configuration

struct Binding: Codable {
    let type: String          // "key", "tap", "mouse", "leftClick", "rightClick", "cycleWindows"
    var key: String?          // keyboard key name (for "key" and "tap")
    var modifiers: [String]?  // "command"/"cmd", "shift", "option"/"alt", "control"/"ctrl"
    var button: Int?          // mouse button number (for "mouse")
}

let defaultConfigJSON = """
{
  "a":              { "key":    "return",      "type": "key"          },
  "b":              { "key":    "escape",      "type": "key"          },
  "x":              { "key":    "backspace",   "type": "key"          },
  "y":              { "key":    "tab",         "type": "key"          },
  "rb":             { "button": 22,            "type": "mouse"        },
  "rt":             { "button": 21,            "type": "mouse"        },
  "back":           { "key":    "o",           "type": "key",           "modifiers": ["control"] },
  "menu":           { "key":    "/",           "type": "key"          },
  "dpad_up":        { "key":    "up",          "type": "key"          },
  "dpad_down":      { "key":    "down",        "type": "key"          },
  "dpad_left":      { "key":    "left",        "type": "key"          },
  "dpad_right":     { "key":    "right",       "type": "key"          },
  "l3":             {                          "type": "leftClick"    },
  "r3":             {                          "type": "rightClick"   },

  "lt+a":           { "key":    "space",       "type": "key"          },
  "lt+b":           { "button": 24,            "type": "mouse"        },
  "lt+x":           { "button": 25,            "type": "mouse"        },
  "lt+y":           { "key":    "tab",         "type": "key",           "modifiers": ["shift"] },
  "lt+rb":          { "button": 27,            "type": "mouse"        },
  "lt+rt":          { "button": 28,            "type": "mouse"        },
  "lt+back":        { "key":    "e",           "type": "key",           "modifiers": ["control"] },
  "lt+menu":        { "button": 26,            "type": "mouse"        },
  "lt+dpad_up":     {                          "type": "cycleWindows" },
  "lt+dpad_down":   {                          "type": "cycleWindows" },
  "lt+dpad_left":   { "key":    "[",           "type": "tap",           "modifiers": ["command", "shift"] },
  "lt+dpad_right":  { "key":    "]",           "type": "tap",           "modifiers": ["command", "shift"] },

  "lb+a":           { "button": 29,            "type": "mouse"        },
  "lb+b":           { "key":    "w",           "type": "key",           "modifiers": ["command"] },
  "lb+x":           { "button": 30,            "type": "mouse"        },
  "lb+y":           { "key":    "t",           "type": "key",           "modifiers": ["command"] },
  "lb+rb":          { "button": 34,            "type": "mouse"        },
  "lb+rt":          { "button": 35,            "type": "mouse"        },
  "lb+back":        { "key":    "b",           "type": "key",           "modifiers": ["control"] },
  "lb+menu":        { "button": 33,            "type": "mouse"        },
  "lb+dpad_up":     { "button": 31,            "type": "mouse"        },
  "lb+dpad_down":   { "button": 32,            "type": "mouse"        },
  "lb+dpad_left":   { "key":    "left",        "type": "tap",           "modifiers": ["control"] },
  "lb+dpad_right":  { "key":    "right",       "type": "tap",           "modifiers": ["control"] }
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
    case "key", "tap":
        let mods = (b.modifiers ?? []).map { $0.capitalized }
        let key = (b.key ?? "?").capitalized
        return (mods + [key]).joined(separator: "+")
    case "mouse":       return "Mouse \(b.button ?? 0)"
    case "leftClick":   return "Left Click"
    case "rightClick":  return "Right Click"
    case "cycleWindows": return "Cycle Windows"
    default:            return b.type
    }
}

// Load bindings from config file, or write defaults
func loadBindings() -> [String: Binding] {
    let configDir = NSString("~/.config").expandingTildeInPath
    let configPath = "\(configDir)/codecontroller.json"

    // Try loading from file
    if FileManager.default.fileExists(atPath: configPath) {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
            let config = try JSONDecoder().decode([String: Binding].self, from: data)
            print("Loaded \(config.count) bindings from \(configPath)")
            return config
        } catch {
            print("ERROR: Failed to parse \(configPath): \(error)")
            print("Using default bindings")
        }
    } else {
        // Write default config
        do {
            try FileManager.default.createDirectory(atPath: configDir, withIntermediateDirectories: true)
            try defaultConfigJSON.write(toFile: configPath, atomically: true, encoding: .utf8)
            print("Wrote default config to \(configPath)")
        } catch {
            print("WARNING: Could not write default config: \(error)")
        }
    }

    // Parse defaults
    return try! JSONDecoder().decode([String: Binding].self, from: defaultConfigJSON.data(using: .utf8)!)
}

var bindings = loadBindings()

// MARK: - State Tracking

var buttonStates: [String: Bool] = [:]
var activeBindings: [String: String] = [:]  // button name -> binding key that was activated

// Scroll momentum
var scrollVelocityX: Float = 0
var scrollVelocityY: Float = 0

// Mouse momentum
var mouseVelocityX: Double = 0
var mouseVelocityY: Double = 0

// Mouse click state
var mouseDown = false
var rightMouseDown = false

// MARK: - Event Simulation

let eventSource = CGEventSource(stateID: .privateState)

func pressKey(_ keyCode: CGKeyCode, down: Bool, modifiers: CGEventFlags = []) {
    let event = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: down)
    event?.flags = modifiers
    event?.post(tap: .cgSessionEventTap)
}

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

func pressMouseButton(_ button: CGMouseButton, down: Bool) {
    let location = CGEvent(source: nil)?.location ?? .zero
    let eventType: CGEventType = down ? .otherMouseDown : .otherMouseUp
    if let event = CGEvent(mouseEventSource: eventSource, mouseType: eventType, mouseCursorPosition: location, mouseButton: button) {
        event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(button.rawValue))
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

func executeBinding(_ binding: Binding, down: Bool) {
    switch binding.type {
    case "key":
        guard let name = binding.key, let code = resolveKeyCode(name) else { return }
        pressKey(code, down: down, modifiers: resolveModifiers(binding.modifiers ?? []))
    case "tap":
        guard down, let name = binding.key, let code = resolveKeyCode(name) else { return }
        tapKey(code, modifiers: resolveModifiers(binding.modifiers ?? []))
    case "mouse":
        guard let btn = binding.button else { return }
        pressMouseButton(CGMouseButton(rawValue: UInt32(btn))!, down: down)
    case "leftClick":
        mouseClick(down: down)
    case "rightClick":
        rightClick(down: down)
    case "cycleWindows":
        if down { cycleWindows() }
    default:
        break
    }
}

func handleButton(_ name: String, pressed: Bool, ltHeld: Bool, lbHeld: Bool) {
    guard buttonStates[name] != pressed else { return }
    buttonStates[name] = pressed

    if pressed {
        // Pick binding: LB layer > LT layer > base
        let bindingKey: String
        if lbHeld, bindings["lb+\(name)"] != nil {
            bindingKey = "lb+\(name)"
        } else if ltHeld, bindings["lt+\(name)"] != nil {
            bindingKey = "lt+\(name)"
        } else {
            bindingKey = name
        }
        activeBindings[name] = bindingKey
        if let binding = bindings[bindingKey] {
            executeBinding(binding, down: true)
            print("\(bindingKey) -> \(describeBinding(binding))")
        }
    } else {
        // Release the same binding that was activated (prevents stuck keys)
        if let bindingKey = activeBindings.removeValue(forKey: name),
           let binding = bindings[bindingKey] {
            executeBinding(binding, down: false)
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
    handleButton("l3",         pressed: gamepad.leftThumbstickButton?.isPressed ?? false,  ltHeld: ltHeld, lbHeld: lbHeld)
    handleButton("r3",         pressed: gamepad.rightThumbstickButton?.isPressed ?? false, ltHeld: ltHeld, lbHeld: lbHeld)
    handleButton("dpad_up",    pressed: gamepad.dpad.up.isPressed,                    ltHeld: ltHeld, lbHeld: lbHeld)
    handleButton("dpad_down",  pressed: gamepad.dpad.down.isPressed,                  ltHeld: ltHeld, lbHeld: lbHeld)
    handleButton("dpad_left",  pressed: gamepad.dpad.left.isPressed,                  ltHeld: ltHeld, lbHeld: lbHeld)
    handleButton("dpad_right", pressed: gamepad.dpad.right.isPressed,                 ltHeld: ltHeld, lbHeld: lbHeld)

    // --- Left stick: mouse movement with momentum ---
    let mouseX = gamepad.leftThumbstick.xAxis.value
    let mouseY = gamepad.leftThumbstick.yAxis.value
    let mouseDeadzone: Float = 0.10
    let mouseSpeed: Double = 20.0
    let mouseAccel: Double = 0.35
    let mouseDecay: Double = 0.7

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
    let deadzone: Float = 0.02
    let scrollSpeed: Float = 30.0
    let accel: Float = 0.15

    if abs(scrollX) > deadzone || abs(scrollY) > deadzone {
        let curvedX = (scrollX > 0 ? 1.0 : -1.0) * pow(abs(scrollX), 5.5) * scrollSpeed
        let curvedY = (scrollY > 0 ? 1.0 : -1.0) * pow(abs(scrollY), 5.5) * scrollSpeed
        scrollVelocityX += (curvedX - scrollVelocityX) * accel
        scrollVelocityY += (curvedY - scrollVelocityY) * accel
    } else {
        let decay: Float = 0.92
        let flat: Float = 1.0
        scrollVelocityX *= decay
        scrollVelocityY *= decay
        if scrollVelocityX > flat { scrollVelocityX -= flat }
        else if scrollVelocityX < -flat { scrollVelocityX += flat }
        else { scrollVelocityX = 0 }
        if scrollVelocityY > flat { scrollVelocityY -= flat }
        else if scrollVelocityY < -flat { scrollVelocityY += flat }
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
        menu.addItem(NSMenuItem(title: "Edit Bindings...", action: #selector(editBindings), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Reload Config", action: #selector(reloadConfig), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Show README", action: #selector(showReadme), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items where item.action != nil {
            item.target = self
        }
        statusItem.menu = menu
    }

    func updateStatus(controllers: [GCController]) {
        if let c = controllers.first {
            statusMenuItem.title = "\(c.vendorName ?? "Controller") connected"
        } else {
            statusMenuItem.title = "No controller"
        }
    }

    @objc func showReadme() {
        guard let readmePath = Bundle.main.path(forResource: "README", ofType: "md"),
              let md = try? String(contentsOfFile: readmePath, encoding: .utf8) else { return }
        // Basic markdown -> HTML (tables, headers, code blocks, bold, backticks)
        var html = md
        // Code blocks
        html = html.replacingOccurrences(of: "```json\n", with: "<pre><code>")
        html = html.replacingOccurrences(of: "```bash\n", with: "<pre><code>")
        html = html.replacingOccurrences(of: "```\n", with: "</code></pre>\n")
        html = html.replacingOccurrences(of: "```", with: "</code></pre>")
        // Headers
        for level in (1...4).reversed() {
            let prefix = String(repeating: "#", count: level)
            html = html.replacingOccurrences(of: "\n\(prefix) ", with: "\n<h\(level)>")
            // Close headers at end of line
            let lines = html.components(separatedBy: "\n")
            html = lines.map { line in
                for l in (1...4).reversed() {
                    if line.hasPrefix("<h\(l)>") && !line.contains("</h\(l)>") {
                        return line + "</h\(l)>"
                    }
                }
                return line
            }.joined(separator: "\n")
        }
        // Tables
        let lines = html.components(separatedBy: "\n")
        var result: [String] = []
        var inTable = false
        for line in lines {
            if line.hasPrefix("|") && line.hasSuffix("|") {
                if line.contains("---") { continue }  // separator row
                let cells = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                if !inTable { result.append("<table border='1' cellpadding='6' cellspacing='0' style='border-collapse:collapse'>"); inTable = true }
                let tag = result.filter({ $0.contains("<tr>") }).isEmpty ? "th" : "td"
                result.append("<tr>" + cells.map { "<\(tag)>\($0)</\(tag)>" }.joined() + "</tr>")
            } else {
                if inTable { result.append("</table>"); inTable = false }
                result.append(line)
            }
        }
        if inTable { result.append("</table>") }
        html = result.joined(separator: "\n")
        // Inline: bold, code
        while let r = html.range(of: "\\*\\*(.+?)\\*\\*", options: .regularExpression) {
            let match = String(html[r])
            html = html.replacingCharacters(in: r, with: "<b>" + match.dropFirst(2).dropLast(2) + "</b>")
        }
        while let r = html.range(of: "`([^`]+)`", options: .regularExpression) {
            let match = String(html[r])
            html = html.replacingCharacters(in: r, with: "<code>" + match.dropFirst(1).dropLast(1) + "</code>")
        }
        // Line breaks for remaining plain lines
        html = html.replacingOccurrences(of: "\n\n", with: "<br><br>")
        let page = """
        <html><head><meta charset="utf-8"><style>
        body { font-family: -apple-system, sans-serif; max-width: 800px; margin: 40px auto; padding: 0 20px; color: #222; }
        table { margin: 10px 0; } th { background: #f0f0f0; text-align: left; }
        code { background: #f4f4f4; padding: 2px 5px; border-radius: 3px; }
        pre code { display: block; padding: 12px; background: #f4f4f4; border-radius: 6px; overflow-x: auto; }
        h1 { border-bottom: 2px solid #ddd; padding-bottom: 8px; }
        h2 { border-bottom: 1px solid #eee; padding-bottom: 6px; margin-top: 30px; }
        </style></head><body>\(html)</body></html>
        """
        let tmpPath = NSTemporaryDirectory() + "codecontroller_readme.html"
        try? page.write(toFile: tmpPath, atomically: true, encoding: .utf8)
        NSWorkspace.shared.open(URL(fileURLWithPath: tmpPath))
    }

    @objc func editBindings() {
        let configPath = NSString("~/.config/codecontroller.json").expandingTildeInPath
        NSWorkspace.shared.open(URL(fileURLWithPath: configPath))
    }

    @objc func reloadConfig() {
        bindings = loadBindings()
        print("Config reloaded (\(bindings.count) bindings)")
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Main

freopen("/tmp/codecontroller.log", "a", stdout)
freopen("/tmp/codecontroller.log", "a", stderr)
setbuf(stdout, nil)
print("CodeController started")

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
