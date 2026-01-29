#!/usr/bin/env swift

import Foundation
import GameController
import CoreGraphics

// MARK: - Configuration

// Mouse button assignments (high numbers that nothing uses)
// BTT can trigger on these
// Order: Face, Sticks, Back/Menu, Bumpers, Triggers

// Normal mode (10-21)
// let mouseA: CGMouseButton = CGMouseButton(rawValue: 10)!
// let mouseB: CGMouseButton = CGMouseButton(rawValue: 11)!
// let mouseX: CGMouseButton = CGMouseButton(rawValue: 12)!
// let mouseY: CGMouseButton = CGMouseButton(rawValue: 13)!
// let mouseL3: CGMouseButton = CGMouseButton(rawValue: 14)!
// let mouseR3: CGMouseButton = CGMouseButton(rawValue: 15)!
let mouseBack: CGMouseButton = CGMouseButton(rawValue: 16)!
let mouseMenu: CGMouseButton = CGMouseButton(rawValue: 17)!
// let mouseLB: CGMouseButton = CGMouseButton(rawValue: 18)!  // modifier
let mouseRB: CGMouseButton = CGMouseButton(rawValue: 19)!
// let mouseLT: CGMouseButton = CGMouseButton(rawValue: 20)!  // modifier
let mouseRT: CGMouseButton = CGMouseButton(rawValue: 21)!

// LT + button (shifted mode, 22-33)
let mouseLT_A: CGMouseButton = CGMouseButton(rawValue: 22)!
let mouseLT_B: CGMouseButton = CGMouseButton(rawValue: 23)!
let mouseLT_X: CGMouseButton = CGMouseButton(rawValue: 24)!
let mouseLT_Y: CGMouseButton = CGMouseButton(rawValue: 25)!
// let mouseLT_L3: CGMouseButton = CGMouseButton(rawValue: 26)!
// let mouseLT_R3: CGMouseButton = CGMouseButton(rawValue: 27)!
// let mouseLT_Back: CGMouseButton = CGMouseButton(rawValue: 28)!
// let mouseLT_Menu: CGMouseButton = CGMouseButton(rawValue: 29)!
// let mouseLT_LB: CGMouseButton = CGMouseButton(rawValue: 30)!
// let mouseLT_RB: CGMouseButton = CGMouseButton(rawValue: 31)!
// let mouseLT_LT: CGMouseButton = CGMouseButton(rawValue: 32)!
// let mouseLT_RT: CGMouseButton = CGMouseButton(rawValue: 33)!

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

// MARK: - Keyboard simulation

// Create isolated event source (won't pick up modifiers from other apps)
let eventSource = CGEventSource(stateID: .privateState)

func pressKey(_ keyCode: CGKeyCode, down: Bool, modifiers: CGEventFlags = []) {
    let event = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: down)
    event?.flags = modifiers
    event?.post(tap: .cgSessionEventTap)
}

func tapKey(_ keyCode: CGKeyCode, modifiers: CGEventFlags = []) {
    pressKey(keyCode, down: true, modifiers: modifiers)
    pressKey(keyCode, down: false, modifiers: modifiers)
}

// Smooth scrolling
func scroll(dx: Int32, dy: Int32) {
    if let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: dy, wheel2: dx, wheel3: 0) {
        event.post(tap: .cghidEventTap)
    }
}

// Mouse movement
func moveMouse(dx: Double, dy: Double) {
    let currentLocation = CGEvent(source: nil)?.location ?? .zero
    let newX = currentLocation.x + dx
    let newY = currentLocation.y + dy
    
    if let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: newX, y: newY), mouseButton: .left) {
        event.post(tap: .cghidEventTap)
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
        event.post(tap: .cghidEventTap)
        print("Mouse \(down ? "DOWN" : "UP")")
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

func handleDpadState(up: Bool, down: Bool, left: Bool, right: Bool, ltHeld: Bool) {
    if dpadStates["up"] != up {
        dpadStates["up"] = up
        if ltHeld && up {
            tapKey(50, modifiers: .maskCommand)  // Cmd+` next window
            print("LT+D-pad UP -> Cmd+`")
        } else {
            pressKey(dpadUp, down: up)
            if up { print("D-pad UP") }
        }
    }
    if dpadStates["down"] != down {
        dpadStates["down"] = down
        if ltHeld && down {
            tapKey(50, modifiers: [.maskCommand, .maskShift])  // Cmd+Shift+` prev window
            print("LT+D-pad DOWN -> Cmd+Shift+`")
        } else {
            pressKey(dpadDown, down: down)
            if down { print("D-pad DOWN") }
        }
    }
    if dpadStates["left"] != left {
        dpadStates["left"] = left
        if ltHeld && left {
            tapKey(33, modifiers: [.maskCommand, .maskShift])  // Cmd+Shift+[ prev tab
            print("LT+D-pad LEFT -> Cmd+Shift+[")
        } else {
            pressKey(dpadLeft, down: left)
            if left { print("D-pad LEFT") }
        }
    }
    if dpadStates["right"] != right {
        dpadStates["right"] = right
        if ltHeld && right {
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
        if ltHeld {
            pressMouseButton(mouseLT_A, down: aPressed)
            if aPressed { print("LT+A -> Mouse 22") }
        } else {
            pressKey(36, down: aPressed)  // Return
            if aPressed { print("A -> Return") }
        }
    }

    let bPressed = gamepad.buttonB.isPressed
    if buttonStates["b"] != bPressed {
        buttonStates["b"] = bPressed
        if ltHeld {
            pressMouseButton(mouseLT_B, down: bPressed)
            if bPressed { print("LT+B -> Mouse 23") }
        } else {
            pressKey(53, down: bPressed)  // Escape
            if bPressed { print("B -> Escape") }
        }
    }

    let xPressed = gamepad.buttonX.isPressed
    if xButtonState != xPressed {
        xButtonState = xPressed
        if ltHeld {
            pressMouseButton(mouseLT_X, down: xPressed)
            if xPressed { print("LT+X -> Mouse 24") }
        } else {
            pressKey(51, down: xPressed)  // Backspace
            if xPressed { print("X -> Backspace") }
        }
    }

    let yPressed = gamepad.buttonY.isPressed
    if yButtonState != yPressed {
        yButtonState = yPressed
        if lbHeld {
            pressKey(17, down: yPressed, modifiers: .maskAlternate)  // Option+T
            if yPressed { print("LB+Y -> Option+T") }
        } else if ltHeld {
            pressKey(48, down: yPressed, modifiers: .maskShift)  // Shift+Tab
            if yPressed { print("LT+Y -> Shift+Tab") }
        } else {
            pressKey(48, down: yPressed)  // Tab
            if yPressed { print("Y -> Tab") }
        }
    }

    // Shoulders
    buttonStates["leftShoulder"] = lbHeld  // LB is a modifier, just track state

    let rbPressed = gamepad.rightShoulder.isPressed
    if buttonStates["rightShoulder"] != rbPressed {
        buttonStates["rightShoulder"] = rbPressed
        pressKey(96, down: rbPressed, modifiers: .maskAlternate)  // Option+F5
        if rbPressed { print("RB -> Option+F5") }
    }

    // Triggers (threshold at 0.5)
    buttonStates["leftTrigger"] = ltHeld  // LT is a modifier, just track state

    let rtPressed = gamepad.rightTrigger.value > 0.5
    if buttonStates["rightTrigger"] != rtPressed {
        buttonStates["rightTrigger"] = rtPressed
        pressMouseButton(mouseRT, down: rtPressed)
        if rtPressed { print("RT -> Mouse 21") }
    }
    
    // D-pad -> Arrow keys (or tab/terminal switching when LT held)
    let dpad = gamepad.dpad
    handleDpadState(
        up: dpad.up.isPressed,
        down: dpad.down.isPressed,
        left: dpad.left.isPressed,
        right: dpad.right.isPressed,
        ltHeld: ltHeld
    )
    
    // Left stick -> Mouse movement
    let mouseX = gamepad.leftThumbstick.xAxis.value
    let mouseY = gamepad.leftThumbstick.yAxis.value
    let mouseDeadzone: Float = 0.10
    let mouseSpeed: Double = 20.0  // Faster cursor
    
    if abs(mouseX) > mouseDeadzone || abs(mouseY) > mouseDeadzone {
        // Apply curve for more aggressive max deflection
        let curvedX = (mouseX > 0 ? 1.0 : -1.0) * pow(Double(abs(mouseX)), 1.5)
        let curvedY = (mouseY > 0 ? 1.0 : -1.0) * pow(Double(abs(mouseY)), 1.5)
        let dx = curvedX * mouseSpeed
        let dy = -curvedY * mouseSpeed  // Invert Y
        moveMouse(dx: dx, dy: dy)
    }
    
    // L3 (left stick click) -> Mouse click
    mouseClick(down: gamepad.leftThumbstickButton?.isPressed ?? false)
    
    // Right stick -> Smooth scrolling
    let scrollX = gamepad.rightThumbstick.xAxis.value
    let scrollY = gamepad.rightThumbstick.yAxis.value
    let deadzone: Float = 0.05
    let scrollSpeed: Float = 25.0  // Higher max speed
    
    if abs(scrollX) > deadzone || abs(scrollY) > deadzone {
        // Apply curve - gentle at low deflection, aggressive at max
        let curvedX = (scrollX > 0 ? 1.0 : -1.0) * pow(abs(scrollX), 2.5)
        let curvedY = (scrollY > 0 ? 1.0 : -1.0) * pow(abs(scrollY), 2.5)
        let dx = Int32(curvedX * scrollSpeed)
        let dy = Int32(curvedY * scrollSpeed)
        scroll(dx: dx, dy: dy)
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

    // Menu button -> /
    let menuPressed = gamepad.buttonMenu.isPressed
    if menuButtonState != menuPressed {
        menuButtonState = menuPressed
        pressKey(44, down: menuPressed)  // /
        if menuPressed { print("Menu -> /") }
    }
}

// MARK: - Main
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
