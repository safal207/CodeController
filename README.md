# CodeController

Gamepad-to-keyboard/mouse remapper for macOS. Maps an Xbox-style controller to keyboard shortcuts, mouse movement, and scrolling — designed for terminal-centric workflows (iTerm2, Claude Code, etc.).

## Features

- **Left stick** — Mouse cursor with momentum and acceleration curve
- **Right stick** — Smooth pixel scrolling with momentum and hybrid decay
- **D-pad** — Arrow keys (with modifier layers for tabs, windows, Spaces)
- **Face buttons** — Common keys (Return, Escape, Backspace) with modifier layers
- **Two modifier layers** — LT (Mod 1) and LB (Mod 2) for extended bindings
- **JSON config** — All bindings in `~/.config/codecontroller.json`, editable without recompiling
- **Virtual mouse buttons** — Unbound slots emit high-numbered mouse buttons for BetterTouchTool

## Default Bindings

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
| A | Return — Term: submit | Space — Term: scroll page | Mouse 29 |
| B | Escape — Claude: cancel | Mouse 24 | Cmd+W — Term: close tab |
| X | Backspace — Term: delete | Mouse 25 | Mouse 30 |
| Y | Tab — Claude: toggle thinking | Shift+Tab — Claude: toggle perm mode | Cmd+T — Term: new tab |
| RB | Mouse 22 | Mouse 27 | Mouse 34 |
| RT | Mouse 21 | Mouse 28 | Mouse 35 |
| Back | Ctrl+O — Claude: toggle verbose | Ctrl+E — Claude: toggle perm explain | Ctrl+B — Claude: background task |
| Menu | / — Claude: slash commands | Mouse 26 | Mouse 33 |

### D-pad

| Direction | Normal | LT (Mod 1) | LB (Mod 2) |
|-----------|--------|-------------|------------|
| Up | Arrow Up — Term: navigate | Cycle windows — macOS | Mouse 31 |
| Down | Arrow Down — Term: navigate | Cycle windows — macOS | Mouse 32 |
| Left | Arrow Left — Term: navigate | Cmd+Shift+[ — Term: prev tab | Ctrl+Left — macOS: prev Space |
| Right | Arrow Right — Term: navigate | Cmd+Shift+] — Term: next tab | Ctrl+Right — macOS: next Space |

### Modifiers

| Button | Role |
|--------|------|
| LT (Left Trigger) | Modifier 1 — held to activate LT layer |
| LB (Left Bumper) | Modifier 2 — held to activate LB layer |

### Mouse Button Reference

Slots marked "Mouse N" emit virtual mouse button N. These do nothing by default but can be mapped to actions in BetterTouchTool or similar.

| Mouse | Trigger | Mouse | Trigger |
|-------|---------|-------|---------|
| Mouse | Trigger | Mouse | Trigger |
| 21 | RT | 29 | LB+A |
| 22 | RB | 30 | LB+X |
| 24 | LT+B | 31 | LB+D-pad Up |
| 25 | LT+X | 32 | LB+D-pad Down |
| 26 | LT+Menu | 33 | LB+Menu |
| 27 | LT+RB | 34 | LB+RB |
| 28 | LT+RT | 35 | LB+RT |

## Configuration

Bindings are stored in `~/.config/codecontroller.json`. A default config is written on first launch. Edit the file and restart the app to apply changes.

### Binding types

| Type | Description | Fields |
|------|-------------|--------|
| `key` | Hold key (press on button down, release on up) | `key`, `modifiers` |
| `tap` | Fire once on press (for shortcuts like Cmd+Shift+[) | `key`, `modifiers` |
| `mouse` | Virtual mouse button (for BetterTouchTool) | `button` |
| `leftClick` | Real left mouse click | — |
| `rightClick` | Real right mouse click | — |
| `cycleWindows` | Raise next window of frontmost app | — |

### Example bindings

```json
{ "type": "key",          "key": "return" }
{ "type": "key",          "key": "w",     "modifiers": ["command"] }
{ "type": "tap",          "key": "[",     "modifiers": ["command", "shift"] }
{ "type": "mouse",        "button": 22 }
{ "type": "leftClick" }
{ "type": "cycleWindows" }
```

### Available key names

Letters (`a`-`z`), numbers (`0`-`9`), `return`, `tab`, `space`, `backspace`, `escape`, `delete`, arrow keys (`up`/`down`/`left`/`right`), function keys (`f1`-`f12`), punctuation (`/`, `[`, `]`, `-`, `=`, `;`, `'`, `,`, `.`, `` ` ``), navigation (`home`, `end`, `pageup`, `pagedown`).

### Available modifiers

`command`/`cmd`, `shift`, `option`/`alt`, `control`/`ctrl`

### Binding keys

Base buttons: `a`, `b`, `x`, `y`, `rb`, `rt`, `back`, `menu`, `l3`, `r3`, `dpad_up`, `dpad_down`, `dpad_left`, `dpad_right`

Prefix with `lt+` or `lb+` for modifier layers (e.g., `lt+a`, `lb+dpad_left`).

## Claude Code Setup

The default bindings map Y to Tab. Claude Code changed Tab from extended thinking toggle to autocomplete (a controversial change). To restore Tab as the thinking toggle, add this to `~/.claude/keybindings.json`:

```json
{
  "bindings": [
    {
      "context": "Chat",
      "bindings": {
        "tab": "chat:thinkingToggle"
      }
    }
  ]
}
```

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
