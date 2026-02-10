#!/usr/bin/env swift

import Foundation
import GameController
import CoreGraphics

// MARK: - Configuration

// Mouse button assignments (high numbers that nothing uses)
// BTT can trigger on these
// Order: Face, Sticks, Back/Menu, Bumpers, Triggers

// Normal (21-22)
let mouseRT: CGMouseButton = CGMouseButton(rawValue: 21)!
let mouseRB: CGMouseButton = CGMouseButton(rawValue: 22)!

// LT + button (23-28)
let mouseLT_A: CGMouseButton = CGMouseButton(rawValue: 23)!
let mouseLT_B: CGMouseButton = CGMouseButton(rawValue: 24)!
let mouseLT_X: CGMouseButton = CGMouseButton(rawValue: 25)!
let mouseLT_Menu: CGMouseButton = CGMouseButton(rawValue: 26)!
let mouseLT_RB: CGMouseButton = CGMouseButton(rawValue: 27)!
let mouseLT_RT: CGMouseButton = CGMouseButton(rawValue: 28)!

// LB + button (29-35)
let mouseLB_A: CGMouseButton = CGMouseButton(rawValue: 29)!
let mouseLB_X: CGMouseButton = CGMouseButton(rawValue: 30)!
let mouseLB_Up: CGMouseButton = CGMouseButton(rawValue: 31)!
let mouseLB_Down: CGMouseButton = CGMouseButton(rawValue: 32)!
let mouseLB_Menu: CGMouseButton = CGMouseButton(rawValue: 33)!
let mouseLB_RB: CGMouseButton = CGMouseButton(rawValue: 34)!
let mouseLB_RT: CGMouseButton = CGMouseButton(rawValue: 35)!

// Helper to send mouse button events
func pressMouseButton(_ button: CGMouseButton, down: Bool) {
    let location = CGEvent(source: nil)?.location ?? .zero
    let eventType: CGEventType = down ? .otherMouseDown : .otherMouseUp
    if let event = CGEvent(mouseEventSource: eventSource, mouseType: eventType, mouseCursorPosition: location, mouseButton: button) {
        event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(button.rawValue))
        event.post(tap: .cgSessionEventTap)
    }
}

// Simple button mappings (no modifiers)
let buttonMappings: [String: CGKeyCode] = [
    "a": 36,           // Return
    "b": 53,           // Escape
]

let dpadUp: CGKeyCode = 126
let dpadDown: CGKeyCode = 125
let dpadLeft: CGKeyCode = 123
let dpadRight: CGKeyCode = 124

// MARK: - State tracking
var buttonStates: [String: Bool] = [:]
var dpadStates: [String: Bool] = ["up": false, "down": false, "left": false, "right": false]
var stickKeyStates: [String: Bool] = ["up": false, "down": false, "left": false, "right": false]
var menuButtonState = false
var optionsButtonState = false
var xButtonState = false
var yButtonState = false

// Scroll momentum
var scrollVelocityX: Float = 0
var scrollVelocityY: Float = 0

// Mouse momentum
var mouseVelocityX: Double = 0
var mouseVelocityY: Double = 0

// MARK: - Keyboard simulation

// Create isolated event source (won't pick up modifiers from other apps)
let eventSource = CGEventSource(stateID: .privateState)

func pressKey(_ keyCode: CGKeyCode, down: Bool, modifiers: CGEventFlags = []) {
    let event = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: down)
    event?.flags = modifiers
    event?.post(tap: .cgSessionEventTap)
}

func tapKey(_ keyCode: CGKeyCode, modifiers: CGEventFlags = []) {
    // Post explicit modifier key events so system shortcuts see real key state
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

// Smooth scrolling
func scroll(dx: Int32, dy: Int32) {
    if let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: dy, wheel2: dx, wheel3: 0) {
        event.post(tap: .cgSessionEventTap)
    }
}

// Mouse movement — use session tap to avoid jitter
func moveMouse(dx: Double, dy: Double) {
    let currentLocation = CGEvent(source: nil)?.location ?? .zero
    let newX = currentLocation.x + dx
    let newY = currentLocation.y + dy

    if let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: newX, y: newY), mouseButton: .left) {
        event.post(tap: .cgSessionEventTap)
    }
}

// Mouse click
var mouseDown = false
func mouseClick(down: Bool) {
    guard mouseDown != down else { return }
    mouseDown = down

    let location = CGEvent(source: nil)?.location ?? .zero
    let eventType: CGEventType = down ? .leftMouseDown : .leftMouseUp

    if let event = CGEvent(mouseEventSource: nil, mouseType: eventType, mouseCursorPosition: location, mouseButton: .left) {
        event.post(tap: .cgSessionEventTap)
        print("Mouse \(down ? "DOWN" : "UP")")
    }
}

var rightMouseDown = false
func rightClick(down: Bool) {
    guard rightMouseDown != down else { return }
    rightMouseDown = down

    let location = CGEvent(source: nil)?.location ?? .zero
    let eventType: CGEventType = down ? .rightMouseDown : .rightMouseUp

    if let event = CGEvent(mouseEventSource: nil, mouseType: eventType, mouseCursorPosition: location, mouseButton: .right) {
        event.post(tap: .cgSessionEventTap)
        print("Right Mouse \(down ? "DOWN" : "UP")")
    }
}

// Track last scroll values for smoothing
var lastScrollX: Float = 0
var lastScrollY: Float = 0

func handleButtonState(_ name: String, pressed: Bool) {
    guard buttonStates[name] != pressed else { return }
    buttonStates[name] = pressed
    
    if let keyCode = buttonMappings[name] {
        pressKey(keyCode, down: pressed)
        print("\(name): \(pressed ? "DOWN" : "UP") -> key \(keyCode)")
    }
}

// Cycle windows of the frontmost app (raises last window to front)
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

func handleDpadState(up: Bool, down: Bool, left: Bool, right: Bool, ltHeld: Bool, lbHeld: Bool) {
    if dpadStates["up"] != up {
        dpadStates["up"] = up
        if lbHeld && up {
            pressMouseButton(mouseLB_Up, down: true)
            pressMouseButton(mouseLB_Up, down: false)
            print("LB+D-pad UP -> Mouse 31")
        } else if ltHeld && up {
            cycleWindows()
            print("LT+D-pad UP -> Cycle window")
        } else {
            pressKey(dpadUp, down: up)
            if up { print("D-pad UP") }
        }
    }
    if dpadStates["down"] != down {
        dpadStates["down"] = down
        if lbHeld && down {
            pressMouseButton(mouseLB_Down, down: true)
            pressMouseButton(mouseLB_Down, down: false)
            print("LB+D-pad DOWN -> Mouse 32")
        } else if ltHeld && down {
            cycleWindows()
            print("LT+D-pad DOWN -> Cycle window")
        } else {
            pressKey(dpadDown, down: down)
            if down { print("D-pad DOWN") }
        }
    }
    if dpadStates["left"] != left {
        dpadStates["left"] = left
        if lbHeld && left {
            tapKey(123, modifiers: .maskControl)  // Ctrl+Left (prev Space)
            print("LB+D-pad LEFT -> Ctrl+Left (prev Space)")
        } else if ltHeld && left {
            tapKey(33, modifiers: [.maskCommand, .maskShift])  // Cmd+Shift+[ prev tab
            print("LT+D-pad LEFT -> Cmd+Shift+[")
        } else {
            pressKey(dpadLeft, down: left)
            if left { print("D-pad LEFT") }
        }
    }
    if dpadStates["right"] != right {
        dpadStates["right"] = right
        if lbHeld && right {
            tapKey(124, modifiers: .maskControl)  // Ctrl+Right (next Space)
            print("LB+D-pad RIGHT -> Ctrl+Right (next Space)")
        } else if ltHeld && right {
            tapKey(30, modifiers: [.maskCommand, .maskShift])  // Cmd+Shift+] next tab
            print("LT+D-pad RIGHT -> Cmd+Shift+]")
        } else {
            pressKey(dpadRight, down: right)
            if right { print("D-pad RIGHT") }
        }
    }
}

func handleStickState(x: Float, y: Float) {
    let deadzone: Float = 0.3
    
    let up = y > deadzone
    let down = y < -deadzone
    let left = x < -deadzone
    let right = x > deadzone
    
    if stickKeyStates["up"] != up {
        stickKeyStates["up"] = up
        pressKey(dpadUp, down: up)
        if up { print("Stick UP") }
    }
    if stickKeyStates["down"] != down {
        stickKeyStates["down"] = down
        pressKey(dpadDown, down: down)
        if down { print("Stick DOWN") }
    }
    if stickKeyStates["left"] != left {
        stickKeyStates["left"] = left
        pressKey(dpadLeft, down: left)
        if left { print("Stick LEFT") }
    }
    if stickKeyStates["right"] != right {
        stickKeyStates["right"] = right
        pressKey(dpadRight, down: right)
        if right { print("Stick RIGHT") }
    }
}

// MARK: - Polling
func pollController(_ gamepad: GCExtendedGamepad) {
    // Read modifiers first
    let ltHeld = gamepad.leftTrigger.value > 0.5
    let lbHeld = gamepad.leftShoulder.isPressed

    // Face buttons - behavior changes when LT is held
    let aPressed = gamepad.buttonA.isPressed
    if buttonStates["a"] != aPressed {
        buttonStates["a"] = aPressed
        if lbHeld {
            pressMouseButton(mouseLB_A, down: aPressed)
            if aPressed { print("LB+A -> Mouse 29") }
        } else if ltHeld {
            pressMouseButton(mouseLT_A, down: aPressed)
            if aPressed { print("LT+A -> Mouse 23") }
        } else {
            pressKey(36, down: aPressed)  // Return
            if aPressed { print("A -> Return") }
        }
    }

    let bPressed = gamepad.buttonB.isPressed
    if buttonStates["b"] != bPressed {
        buttonStates["b"] = bPressed
        if lbHeld {
            pressKey(13, down: bPressed, modifiers: .maskCommand)  // Cmd+W (close tab)
            if bPressed { print("LB+B -> Cmd+W") }
        } else if ltHeld {
            pressMouseButton(mouseLT_B, down: bPressed)
            if bPressed { print("LT+B -> Mouse 24") }
        } else {
            pressKey(53, down: bPressed)  // Escape
            if bPressed { print("B -> Escape") }
        }
    }

    let xPressed = gamepad.buttonX.isPressed
    if xButtonState != xPressed {
        xButtonState = xPressed
        if lbHeld {
            pressMouseButton(mouseLB_X, down: xPressed)
            if xPressed { print("LB+X -> Mouse 30") }
        } else if ltHeld {
            pressMouseButton(mouseLT_X, down: xPressed)
            if xPressed { print("LT+X -> Mouse 25") }
        } else {
            pressKey(51, down: xPressed)  // Backspace
            if xPressed { print("X -> Backspace") }
        }
    }

    let yPressed = gamepad.buttonY.isPressed
    if yButtonState != yPressed {
        yButtonState = yPressed
        if lbHeld {
            pressKey(17, down: yPressed, modifiers: .maskCommand)  // Cmd+T (new tab)
            if yPressed { print("LB+Y -> Cmd+T") }
        } else if ltHeld {
            pressKey(48, down: yPressed, modifiers: .maskShift)  // Shift+Tab
            if yPressed { print("LT+Y -> Shift+Tab") }
        } else {
            pressKey(17, down: yPressed, modifiers: .maskAlternate)  // Option+T
            if yPressed { print("Y -> Option+T") }
        }
    }

    // Shoulders
    buttonStates["leftShoulder"] = lbHeld  // LB is a modifier, just track state

    let rbPressed = gamepad.rightShoulder.isPressed
    if buttonStates["rightShoulder"] != rbPressed {
        buttonStates["rightShoulder"] = rbPressed
        if lbHeld {
            pressMouseButton(mouseLB_RB, down: rbPressed)
            if rbPressed { print("LB+RB -> Mouse 34") }
        } else if ltHeld {
            pressMouseButton(mouseLT_RB, down: rbPressed)
            if rbPressed { print("LT+RB -> Mouse 27") }
        } else {
            pressMouseButton(mouseRB, down: rbPressed)
            if rbPressed { print("RB -> Mouse 22") }
        }
    }

    // Triggers (threshold at 0.5)
    buttonStates["leftTrigger"] = ltHeld  // LT is a modifier, just track state

    let rtPressed = gamepad.rightTrigger.value > 0.5
    if buttonStates["rightTrigger"] != rtPressed {
        buttonStates["rightTrigger"] = rtPressed
        if lbHeld {
            pressMouseButton(mouseLB_RT, down: rtPressed)
            if rtPressed { print("LB+RT -> Mouse 35") }
        } else if ltHeld {
            pressMouseButton(mouseLT_RT, down: rtPressed)
            if rtPressed { print("LT+RT -> Mouse 28") }
        } else {
            pressMouseButton(mouseRT, down: rtPressed)
            if rtPressed { print("RT -> Mouse 21") }
        }
    }
    
    // D-pad -> Arrow keys (or tab/terminal switching when LT held)
    let dpad = gamepad.dpad
    handleDpadState(
        up: dpad.up.isPressed,
        down: dpad.down.isPressed,
        left: dpad.left.isPressed,
        right: dpad.right.isPressed,
        ltHeld: ltHeld,
        lbHeld: lbHeld
    )
    
    // Left stick -> Mouse movement with light momentum
    let mouseX = gamepad.leftThumbstick.xAxis.value
    let mouseY = gamepad.leftThumbstick.yAxis.value
    let mouseDeadzone: Float = 0.10
    let mouseSpeed: Double = 20.0
    let mouseAccel: Double = 0.35    // faster response than scroll
    let mouseDecay: Double = 0.7     // quick falloff

    if abs(mouseX) > mouseDeadzone || abs(mouseY) > mouseDeadzone {
        let curvedX = (mouseX > 0 ? 1.0 : -1.0) * pow(Double(abs(mouseX)), 1.5) * mouseSpeed
        let curvedY = (mouseY > 0 ? 1.0 : -1.0) * pow(Double(abs(mouseY)), 1.5) * mouseSpeed
        mouseVelocityX += (curvedX - mouseVelocityX) * mouseAccel
        mouseVelocityY += (-curvedY - mouseVelocityY) * mouseAccel  // Invert Y
    } else {
        mouseVelocityX *= mouseDecay
        mouseVelocityY *= mouseDecay
    }

    if abs(mouseVelocityX) > 0.3 || abs(mouseVelocityY) > 0.3 {
        moveMouse(dx: mouseVelocityX, dy: mouseVelocityY)
    }
    
    // L3 (left stick click) -> Mouse click
    mouseClick(down: gamepad.leftThumbstickButton?.isPressed ?? false)
    // R3 (right stick click) -> Right click
    rightClick(down: gamepad.rightThumbstickButton?.isPressed ?? false)
    
    // Right stick -> Smooth scrolling with momentum
    let scrollX = gamepad.rightThumbstick.xAxis.value
    let scrollY = gamepad.rightThumbstick.yAxis.value
    let deadzone: Float = 0.02
    let scrollSpeed: Float = 30.0
    let accel: Float = 0.15      // build-up rate

    if abs(scrollX) > deadzone || abs(scrollY) > deadzone {
        // Apply steeper curve - more difference between min and max
        let curvedX = (scrollX > 0 ? 1.0 : -1.0) * pow(abs(scrollX), 5.5) * scrollSpeed
        let curvedY = (scrollY > 0 ? 1.0 : -1.0) * pow(abs(scrollY), 5.5) * scrollSpeed
        // Accelerate toward target velocity
        scrollVelocityX += (curvedX - scrollVelocityX) * accel
        scrollVelocityY += (curvedY - scrollVelocityY) * accel
    } else {
        // Hybrid decay: multiplicative + flat subtraction
        // Flat part makes high velocity stop sooner (relatively)
        let decay: Float = 0.92
        let flat: Float = 1.0
        scrollVelocityX *= decay
        scrollVelocityY *= decay
        // Subtract flat amount toward zero
        if scrollVelocityX > flat { scrollVelocityX -= flat }
        else if scrollVelocityX < -flat { scrollVelocityX += flat }
        else { scrollVelocityX = 0 }
        if scrollVelocityY > flat { scrollVelocityY -= flat }
        else if scrollVelocityY < -flat { scrollVelocityY += flat }
        else { scrollVelocityY = 0 }
    }

    // Scroll if velocity above threshold
    if abs(scrollVelocityX) > 0.5 || abs(scrollVelocityY) > 0.5 {
        scroll(dx: -Int32(scrollVelocityX), dy: Int32(scrollVelocityY))
    }
    
    // Back/View button -> Ctrl+O (or Ctrl+E when LT held, or Ctrl+B when LB held)
    let optionsPressed = gamepad.buttonOptions?.isPressed ?? false
    if optionsButtonState != optionsPressed {
        optionsButtonState = optionsPressed
        if lbHeld {
            pressKey(11, down: optionsPressed, modifiers: .maskControl)  // Ctrl+B
            if optionsPressed { print("LB+Back -> Ctrl+B") }
        } else if ltHeld {
            pressKey(14, down: optionsPressed, modifiers: .maskControl)  // Ctrl+E
            if optionsPressed { print("LT+Back -> Ctrl+E") }
        } else {
            pressKey(31, down: optionsPressed, modifiers: .maskControl)  // Ctrl+O
            if optionsPressed { print("Back -> Ctrl+O") }
        }
    }

    // Menu button -> / (or mouse button with modifiers)
    let menuPressed = gamepad.buttonMenu.isPressed
    if menuButtonState != menuPressed {
        menuButtonState = menuPressed
        if lbHeld {
            pressMouseButton(mouseLB_Menu, down: menuPressed)
            if menuPressed { print("LB+Menu -> Mouse 33") }
        } else if ltHeld {
            pressMouseButton(mouseLT_Menu, down: menuPressed)
            if menuPressed { print("LT+Menu -> Mouse 26") }
        } else {
            pressKey(44, down: menuPressed)  // /
            if menuPressed { print("Menu -> /") }
        }
    }
}

// MARK: - Main
freopen("/tmp/codecontroller.log", "a", stdout)
freopen("/tmp/codecontroller.log", "a", stderr)
setbuf(stdout, nil)
print("CodeController (polling mode)")
print("Press Ctrl+C to quit\n")

GCController.startWirelessControllerDiscovery {}

var lastControllerCount = 0
var noControllerTicks = 0

// Poll at 60Hz
Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { _ in
    let controllers = GCController.controllers()
    
    if controllers.count != lastControllerCount {
        lastControllerCount = controllers.count
        noControllerTicks = 0
        print("Controllers: \(controllers.count)")
        for c in controllers {
            print("  - \(c.vendorName ?? "Unknown") (\(c.productCategory))")
        }
    }
    
    // Auto-reconnect: if no controllers for 5 seconds, retry discovery
    if controllers.isEmpty {
        noControllerTicks += 1
        if noControllerTicks == 300 {  // 5 seconds at 60Hz
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

RunLoop.main.run()
