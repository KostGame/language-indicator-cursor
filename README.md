# Language Indicator Cursor for Windows

Fork of `yakunins/language-indicator`, tuned for a simple multi-monitor use case: **always show the active RU/EN keyboard language next to the mouse pointer**.

## Fork behavior

- Windows 11/10, AutoHotkey v2.
- A small flag follows the mouse pointer on any monitor.
- **Russian** layouts use `img/flags-png/ru.png`.
- **English** layouts (US, UK, etc.) use `img/flags-png/us.png`.
- Layout identity is resolved from the actual Windows `HKL/LANGID`, not from the order in which layouts were encountered after startup.
- The marker is visible over ordinary UI and is **not limited to the I-beam text cursor**.
- The Windows system cursor is never replaced.
- The marker overlay is non-activating and click-through.
- Caps Lock does not change the language flag.
- Other languages currently hide the marker.
- The original text-caret indicator remains in the codebase but is disabled by default in this fork.

The source flag images are 8×6 pixels and are displayed at 2× size by default, so the visible marker is approximately 16×12 pixels.

## Installation

1. Download/unzip a build of this fork.
2. Run `install.cmd`.
3. Start `language-indicator.exe` once if it is not already running.

`install.cmd` creates a shortcut in the current user's Windows Startup folder so the indicator starts automatically after sign-in.

To remove the startup shortcut, run `uninstall.cmd`.

## Development

The application entry point is `language-indicator.ahk`.

### Tests

Run the AutoHotkey v2 console test suite:

```text
tests\RunTestsConsole.ahk
```

The fork adds tests for direct Windows locale-to-flag mapping, including Russian and multiple English LANGIDs.

### Compile

With AutoHotkey v2 and Ahk2Exe installed in the standard location:

```text
tools\compile.cmd
```

The compiler writes `language-indicator.exe` in the repository root.

## Relevant implementation

- `lib/CursorIndicator.ahk` follows the mouse and selects the RU/EN flag.
- `lib/detection/GetInputLocaleId.ahk` reads the keyboard layout of the active foreground window.
- `lib/detection/GetLanguageFlagCode.ahk` maps Windows primary language IDs to `ru` / `us` flag assets.
- `lib/image-utils/ImagePainter.ahk` paints the transparent click-through overlay and scales the tiny flag assets.

## Upstream

Original project: `yakunins/language-indicator`.

The upstream project supports per-language styling of both the text caret and mouse I-beam cursor, including `.cur`, `.ani`, `.ico`, and `.png` customization. This fork intentionally narrows the default behavior to an always-near-pointer RU/EN indicator for multi-monitor work.

## License

MIT, as in the upstream project.
