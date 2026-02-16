# CodeController

Write software entirely using an Xbox controller and your voice. Maps every control you need for a voice-first, multi-terminal, agentic workflow to your gamepad.

Sit, stand, or walk around while developing software faster than ever.

## Features

- **Face buttons** — Common keys (Return, Escape, Backspace, Tab) with modifier layers

- **D-pad** — Arrow keys, with modifier layers for tab and window switching

- **Two modifier layers** — Hold LT or LB to access extended bindings on every button

- **Left stick** — Moves mouse cursor (fallback for when buttons won't do)

- **Right stick** — Smooth scrolling

- **Universal mouse buttons** — Any button combo without a keyboard binding automatically emits a virtual mouse button (10–51), mappable in utilities like [SuperWhisper](https://superwhisper.com) or [BetterTouchTool](https://folivora.ai)

- **JSON config** — All bindings stored in `~/.config/codecontroller.json`, editable without recompiling

## Requirements

- macOS 10.15+
- Xbox One wireless controller (known supported — other controllers may work via Apple's Game Controller framework)

## Setup

Check the [Releases](../../releases) page for pre-built binaries.

### Building from Source

Requires Swift toolchain (Xcode or Command Line Tools).

1. Build: `./build.sh`
2. Copy to Applications: `cp -R CodeController.app /Applications/`
3. Launch: `open /Applications/CodeController.app`
4. Grant **Accessibility** permission when prompted (or manually in System Settings > Privacy & Security > Accessibility)

### SuperWhisper (Voice Input)

[SuperWhisper](https://superwhisper.com) is a macOS voice-to-text app. Bind controller buttons to SuperWhisper for hands-free dictation:

1. Install SuperWhisper
2. Open SuperWhisper Settings
3. Set Mouse Shortcut to **Mouse Button 14** (RT)

### Claude Code Keybindings

The default bindings map Y to Tab. Claude Code changed Tab from extended thinking toggle to autocomplete. To restore Tab as the thinking toggle, add this to `~/.claude/keybindings.json`:

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

## Default Bindings

Every button has a default mouse button number shown in the **#** column. The config file contains keyboard overrides — remove an override to expose the underlying mouse button.

### Sticks

| Input | Action | # |
|-------|--------|---|
| Left Stick | Mouse cursor | |
| Left Stick Click | Left click | 16 |
| Right Stick | Scroll | |
| Right Stick Click | Right click | 17 |

### Modifiers

| Button | Role |
|--------|------|
| **LT** (Left Trigger) | Hold to activate +LT layer |
| **LB** (Left Bumper) | Hold to activate +LB layer |

### Base

| Button | Key | Action | # |
|--------|-----|--------|---|
| **A** | `Return` | Submit | 10 |
| **B** | `Escape` | Cancel | 11 |
| **X** | `Backspace` | Delete | 12 |
| **Y** | `Tab` | Autocomplete / thinking | 13 |
| **RT** | | | 14 |
| **RB** | | | 15 |
| **D-Up** | `Up` | Navigate | 18 |
| **D-Down** | `Down` | Navigate | 19 |
| **D-Left** | `Left` | Navigate | 20 |
| **D-Right** | `Right` | Navigate | 21 |
| **Back** | `Ctrl+O` | Toggle transcript | 22 |
| **Menu** | `/` | Slash commands | 23 |

### +LT

| Button | Key | Action | # |
|--------|-----|--------|---|
| **LT+A** | `Space` | Scroll page | 24 |
| **LT+B** | | | 25 |
| **LT+X** | | | 26 |
| **LT+Y** | `Shift+Tab` | Cycle permission mode | 27 |
| **LT+RT** | | | 28 |
| **LT+RB** | | | 29 |
| **LT+LS** | | | 30 |
| **LT+RS** | | | 31 |
| **LT+D-Up** | `<Accessibility>` | Cycle windows | 32 |
| **LT+D-Down** | `<Accessibility>` | Cycle windows | 33 |
| **LT+D-Left** | `Cmd+Shift+[` | Prev tab | 34 |
| **LT+D-Right** | `Cmd+Shift+]` | Next tab | 35 |
| **LT+Back** | `Ctrl+E` | Toggle show all | 36 |
| **LT+Menu** | | | 37 |

### +LB

| Button | Key | Action | # |
|--------|-----|--------|---|
| **LB+A** | | | 38 |
| **LB+B** | `Cmd+W` | Close tab | 39 |
| **LB+X** | | | 40 |
| **LB+Y** | `Cmd+T` | New tab | 41 |
| **LB+RT** | | | 42 |
| **LB+RB** | | | 43 |
| **LB+LS** | | | 44 |
| **LB+RS** | | | 45 |
| **LB+D-Up** | | | 46 |
| **LB+D-Down** | | | 47 |
| **LB+D-Left** | | | 48 |
| **LB+D-Right** | | | 49 |
| **LB+Back** | `Ctrl+B` | Background task | 50 |
| **LB+Menu** | | | 51 |

## Configuration

Bindings are stored in `~/.config/codecontroller.json`. A default config is written on first launch. Edit the file and use **Reload Config** from the menu bar to apply changes.

The config only needs entries for keyboard overrides. Any button combo not in the config automatically emits its mouse button.

### Binding Types

| Type | Description | Fields |
|------|-------------|--------|
| `key` | Hold key (press on button down, release on up) | `key`, `modifiers` |
| `tap` | Fire once on press with explicit modifier key events — use for system shortcuts (e.g. `Cmd+Shift+[`) that don't register with `key` | `key`, `modifiers` |
| `leftClick` | Left mouse click | — |
| `rightClick` | Right mouse click | — |
| `cycleWindows` | Raise next window of frontmost app | — |

### Example Bindings

```json
{ "key": "return",  "type": "key" }
{ "key": "w",       "type": "key",   "modifiers": ["command"] }
{ "key": "[",       "type": "tap",   "modifiers": ["command", "shift"] }
{ "type": "leftClick" }
{ "type": "cycleWindows" }
```

### Key Names

- Letters: `a` through `z`
- Numbers: `0` through `9`
- Editing: `return`, `tab`, `space`, `backspace`, `escape`, `delete`
- Arrows: `up`, `down`, `left`, `right`
- Function: `f1` through `f12`
- Punctuation: `/`, `[`, `]`, `-`, `=`, `;`, `'`, `,`, `.`, `` ` ``
- Navigation: `home`, `end`, `pageup`, `pagedown`

### Modifier Names

- `command` or `cmd`
- `shift`
- `option` or `alt`
- `control` or `ctrl`

### Binding Keys

Base buttons:

`a`, `b`, `x`, `y`, `rt`, `rb`, `ls`, `rs`, `back`, `menu`, `dpad_up`, `dpad_down`, `dpad_left`, `dpad_right`

Prefix with `lt+` or `lb+` for modifier layers (e.g., `lt+a`, `lb+dpad_left`).

## Logs

Output is logged to `~/Library/Logs/CodeController.log`.
