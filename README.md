# Language Indicator Cursor for Windows

Fork of `yakunins/language-indicator`, tuned for a simple multi-monitor use case: keep the active RU/EN keyboard language close to where you are working, next to the mouse pointer and the active text caret.

## Fork behavior

- Windows 11/10, AutoHotkey v2.
- A small flag follows the mouse pointer on any monitor while the mouse is active.
- The mouse flag automatically hides after 3 seconds without mouse movement and reappears immediately when the mouse moves again.
- When an active text caret can be detected, the same language flag is also shown next to the insertion point. The caret flag is not hidden by mouse inactivity, so it remains useful while typing.
- **Russian** layouts use `img/flags-png/ru.png`.
- **English** layouts (US, UK, etc.) use `img/flags-png/us.png`.
- Layout identity is resolved from the actual Windows `HKL/LANGID`, not from the order in which layouts were encountered after startup.
- The mouse marker works over ordinary UI and is **not limited to the I-beam text cursor**.
- The Windows system cursor is never replaced.
- Marker overlays are non-activating and click-through.
- Caps Lock does not change the language flag.
- Other languages currently hide the markers.

The source flag images are 8×6 pixels and are displayed at 2× size by default, so the visible marker is approximately 16×12 pixels.

The mouse idle timeout is controlled by `cursor.mouseIdleHideAfter` in `language-indicator.ahk`. The default is `3000` milliseconds. Set it to `0` or a negative value to disable idle hiding.

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

The fork adds tests for direct Windows locale-to-flag mapping, including Russian and multiple English LANGIDs, cursor/caret flag configuration, and mouse-idle visibility behavior.

### Compile

With AutoHotkey v2 and Ahk2Exe installed in the standard location:

```text
tools\compile.cmd
```

The compiler writes `language-indicator.exe` in the repository root.

## Relevant implementation

- `lib/CursorIndicator.ahk` follows the mouse, selects the RU/EN flag, and handles the idle timeout.
- `lib/CaretIndicator.ahk` follows the active text caret and uses the same RU/EN mapping.
- `lib/detection/GetInputLocaleId.ahk` reads the keyboard layout of the active foreground window.
- `lib/detection/GetLanguageFlagCode.ahk` maps Windows primary language IDs to `ru` / `us` flag assets.
- `lib/image-utils/ImagePainter.ahk` paints transparent click-through overlays and scales the tiny flag assets.

## Limitations

Caret position detection depends on what the target application exposes to Windows. Standard Win32 controls and many modern applications are supported by the upstream detection stack, but some custom-rendered editors may not expose a usable caret position. In that case the mouse flag continues to work normally.

## Upstream

Original project: `yakunins/language-indicator`.

The upstream project supports per-language styling of both the text caret and mouse I-beam cursor, including `.cur`, `.ani`, `.ico`, and `.png` customization. This fork keeps that detection machinery but narrows the default visual behavior to explicit RU/EN flags for multi-monitor work.

## License

MIT, as in the upstream project.
