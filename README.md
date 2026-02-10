# CodeController

Gamepad-to-keyboard/mouse remapper for macOS. Maps an Xbox-style controller to keyboard shortcuts, mouse movement, and scrolling — designed for terminal-centric workflows (iTerm2, Claude Code, etc.).

## Features

- **Left stick** — Mouse cursor with momentum and acceleration curve
- **Right stick** — Smooth pixel scrolling with momentum and hybrid decay
- **D-pad** — Arrow keys (with modifier layers for tabs, windows, Spaces)
- **Face buttons** — Common keys (Return, Escape, Backspace) with modifier layers
- **Two modifier layers** — LT (Mod 1) and LB (Mod 2) for extended bindings
- **High-numbered mouse buttons** — Unbound slots emit virtual mouse buttons (10–45) for BetterTouchTool or other tools to pick up

## Button Mapping

### Sticks

| Input | Action |
|-------|--------|
| Left Stick | Mouse movement |
| L3 (left stick click) | Left click |
| Right Stick | Scroll |
| R3 (right stick click) | Right click |

### Buttons

| Button | Normal | LT (Mod 1) | LB (Mod 2) |
|--------|--------|-------------|------------|
| A | Return | Mouse 22 | Mouse 34 |
| B | Escape | Mouse 23 | Cmd+W (close tab) |
| X | Backspace | Mouse 24 | Mouse 36 |
| Y | Option+T (thinking) | Shift+Tab (perm mode) | Cmd+T (new tab) |
| RB | Mouse 19 | Mouse 31 | Mouse 43 |
| RT | Mouse 21 | — | — |
| Back/Options | Ctrl+O (verbose) | Ctrl+E (perm explain) | Ctrl+B (background) |
| Menu | / | Mouse 29 | Mouse 41 |

### D-pad

| Direction | Normal | LT (Mod 1) | LB (Mod 2) |
|-----------|--------|-------------|------------|
| Up | Arrow Up | Cycle windows | — |
| Down | Arrow Down | Cycle windows | — |
| Left | Arrow Left | Cmd+Shift+[ (prev tab) | Ctrl+Left (prev Space) |
| Right | Arrow Right | Cmd+Shift+] (next tab) | Ctrl+Right (next Space) |

### Modifiers

| Button | Role |
|--------|------|
| LT (Left Trigger) | Modifier 1 — held to activate LT layer |
| LB (Left Bumper) | Modifier 2 — held to activate LB layer |

### Mouse Button Reference

Slots marked "Mouse N" emit virtual mouse button N. These do nothing by default but can be mapped to actions in BetterTouchTool or similar.

| Mouse Button | Trigger |
|--------------|---------|
| 19 | RB |
| 21 | RT |
| 22 | LT+A |
| 23 | LT+B |
| 24 | LT+X |
| 29 | LT+Menu |
| 31 | LT+RB |
| 34 | LB+A |
| 36 | LB+X |
| 41 | LB+Menu |
| 43 | LB+RB |

## Setup

1. Build:
   ```bash
   ./build.sh
   ```
2. Install:
   ```bash
   cp -R CodeController.app /Applications/
   open /Applications/CodeController.app
   ```
3. Grant **Accessibility** permission to CodeController in System Settings > Privacy & Security > Accessibility.

## Requirements

- macOS 10.15+
- Swift toolchain (Xcode or Command Line Tools)
- A gamepad supported by Apple's Game Controller framework (Xbox, PlayStation, MFi)

## Logs

Output is logged to `/tmp/codecontroller.log`.
