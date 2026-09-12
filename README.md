# Language Indicator Cursor for Windows

Fork of `yakunins/language-indicator`, tuned for a multi-monitor use case: keep the active RU/EN keyboard language close to where you are working, next to the mouse pointer and the active text caret.

## Fork behavior

- Windows 11/10, AutoHotkey v2.
- A small flag follows the mouse pointer on any monitor while the mouse is active.
- The mouse flag automatically hides after 3 seconds without mouse movement and reappears immediately when the mouse moves again.
- When an active text caret can be detected, the same language flag is also shown next to the insertion point. The caret flag is not hidden by mouse inactivity, so it remains useful while typing.
- **Russian** layouts use `img/flags-png/ru.png`.
- **English** layouts (US, UK, etc.) use `img/flags-png/us.png`.
- Layout identity is resolved from the actual Windows `HKL/LANGID`, not from the order in which layouts were encountered after startup.
- The Windows system cursor is never replaced.
- Marker overlays are non-activating and click-through.
- Caps Lock does not change the language flag.
- Other languages currently hide the markers.

The source flag images are 8×6 pixels and are displayed at 2× size by default, so the visible marker is approximately 16×12 pixels.

## Settings

Open the tray icon and choose **Настройки...**.

### Mouse indicator

- **Показывать у мыши** on/off.
- Opacity in percent.
- Horizontal offset X in pixels.
- Vertical offset Y in pixels.
- Idle hide delay in seconds (`0` disables auto-hide).

### Text-caret indicator

- **Показывать в поле ввода** on/off.
- Opacity in percent.
- Horizontal offset X in pixels.
- Vertical offset Y in pixels. Negative Y moves the flag upward, away from typed text.

Defaults are intentionally different: the mouse flag is about 90% opaque, while the text-caret flag is about 70% opaque and raised above the text line so it does not cover the word being typed. All of these values can be changed from the tray settings window.

Settings are stored per user in:

```text
%APPDATA%\LanguageIndicatorCursor\settings.ini
```

Saving settings automatically restarts the application so the new configuration takes effect.

## Installation

1. Download/unzip a build of this fork.
2. Run `install.cmd`.
3. Start `language-indicator.exe` once if it is not already running.

`install.cmd` creates a shortcut in the current user's Windows Startup folder so the indicator starts automatically after sign-in.

To remove the startup shortcut, run `uninstall.cmd`.

## Windows SmartScreen

Development builds are currently **unsigned**, so Windows SmartScreen can show `Unknown publisher` / `Windows protected your PC` for a newly downloaded EXE. This is a publisher/reputation warning rather than a malware verdict from this application.

For a polished public release, the executable should be Authenticode-signed with a trusted code-signing certificate. Rebuilding the EXE changes its hash, so unsigned development builds can trigger SmartScreen again even after an earlier build was allowed.

## Development

The application entry point is `language-indicator.ahk`.

### Tests

Run the AutoHotkey v2 console test suite:

```text
tests\RunTestsConsole.ahk
```

The fork adds tests for direct Windows locale-to-flag mapping, including Russian and multiple English LANGIDs, cursor/caret flag configuration, opacity, position defaults, and mouse-idle visibility behavior.

### Compile

With AutoHotkey v2 and Ahk2Exe installed in the standard location:

```text
tools\compile.cmd
```

The compiler writes `language-indicator.exe` in the repository root.

## Relevant implementation

- `lib/CursorIndicator.ahk` follows the mouse, selects the RU/EN flag, and handles the idle timeout.
- `lib/CaretIndicator.ahk` follows the active text caret and uses the same RU/EN mapping.
- `lib/SettingsManager.ahk` loads, saves, and displays the per-user settings GUI.
- `lib/detection/GetInputLocaleId.ahk` reads the keyboard layout of the active foreground window.
- `lib/detection/GetLanguageFlagCode.ahk` maps Windows primary language IDs to `ru` / `us` flag assets.
- `lib/image-utils/ImagePainter.ahk` paints transparent click-through overlays with configurable opacity.

## Limitations

Caret position detection depends on what the target application exposes to Windows. Standard Win32 controls and many modern applications are supported by the upstream detection stack, but some custom-rendered editors may not expose a usable caret position. In that case the mouse flag continues to work normally.

## Upstream

Original project: `yakunins/language-indicator`.

The upstream project supports per-language styling of both the text caret and mouse I-beam cursor, including `.cur`, `.ani`, `.ico`, and `.png` customization. This fork keeps that detection machinery but narrows the default visual behavior to explicit RU/EN flags for multi-monitor work.

## License

MIT, as in the upstream project.
