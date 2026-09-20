# Language Indicator Cursor for Windows

Fork of `yakunins/language-indicator`, tuned for a multi-monitor RU/EN workflow. The primary mode shows the active keyboard language next to the text caret so the layout is visible exactly where you type. An optional mouse-following flag is still available from the tray menu, but is disabled by default.

## 0.80: colored system cursors

`0.80-kost.1` adds a second language cue that does not depend on caret detection: the actual Windows system cursor receives a thin colored outline.

- **RU**: red accent (`#E53935`).
- **EN**: blue accent (`#2F80ED`).
- Covered roles include Arrow, IBeam, Hand, Cross, resize/move, unavailable, help, pin and person.
- The original cursor geometry and hotspot are preserved; only a thin outline is added.
- Animated `Wait` and `AppStarting` cursors are intentionally left unchanged so Windows animation is not frozen into a static frame.
- On normal app exit/reload, the cursor set captured at startup is restored.
- Apps that draw a completely custom cursor can still override the system cursor.

The feature is enabled by default and can be disabled from the tray menu under `Цвет системных курсоров`.

## Fork behavior

- Windows 11/10, AutoHotkey v2.
- When an active text caret can be detected, a small RU/EN flag is shown next to the insertion point.
- The caret flag follows typing and is not hidden by mouse inactivity.
- An optional mouse flag can be enabled from the tray menu. When enabled, it follows the pointer, hides after the configured idle period, and wakes on movement or a real RU↔EN layout change.
- **Russian** layouts use `img/flags-png/ru.png`.
- **English** layouts (US, UK, etc.) use `img/flags-png/us.png`.
- Layout identity is resolved from the actual Windows `HKL/LANGID`, not from discovery order.
- Marker overlays are non-activating and click-through.
- Caps Lock does not change the language flag.
- Unsupported/transient helper layouts do not erase the last valid RU/EN flag.
- Caret probing runs in a separate worker process with heartbeat/watchdog recovery so a bad target application does not take down the mouse/tray process.
- Stale caret and mouse overlays are destroyed on invalid/focus-loss states to avoid persistent visual ghosts.
- Large caret-coordinate jumps rebuild the caret overlay and flush DWM composition before repaint, reducing stale overlay copies during Chromium/Electron partial page redraws.

The source flag images are 8×6 pixels and are displayed at 2× size by default, so the visible marker is approximately 16×12 pixels.

## Settings

All settings live directly in the tray menu. There is no separate settings window.

### `В поле ввода`

- **Показывать в поле ввода** on/off.
- **Непрозрачность**: 40–100% presets (`100%` = fully visible).
- **Положение**: move the flag up/down/left/right in 2 px steps, or reset to the default position.

The text-caret flag is enabled by default, uses about 70% opacity, and is raised above the text line so it does not cover the word being typed.

### `Цвет системных курсоров`

- **Красный RU / синий EN** on/off.
- Enabled by default in 0.80.
- Works independently of the floating mouse flag and does not require caret geometry.

### `У мыши`

- **Показывать у мыши** on/off.
- **Непрозрачность**: 40–100% presets (`100%` = fully visible, `40%` = strongly transparent).
- **Положение**: move the flag up/down/left/right in 2 px steps, or reset to the default position.
- **Скрывать через**: never / 1 / 2 / 3 / 5 / 10 seconds.

The mouse flag remains available as an optional mode but is disabled by default.

Settings are stored per user in:

```text
%APPDATA%\LanguageIndicatorCursor\settings.ini
```

Each tray change is persisted and the indicator reloads automatically so the new value takes effect. Existing installations keep their previously saved mouse/caret settings when upgrading.

## Runtime recovery / diagnostics

Foreground focus changes can briefly make Windows input-locale or caret APIs unavailable. The fork contains timer exception containment, transient-locale recovery, stale-overlay destruction/recreation, last-valid RU/EN retention, a separate caret worker, and a watchdog so one bad focus transition does not permanently stop updates.

Input-locale sampling uses a 20 ms cadence for the caret/mouse overlays. The 0.80 system-cursor color watcher switches only when the resolved RU/EN state changes.

If a runtime error occurs, a throttled diagnostic log is written to:

```text
%APPDATA%\LanguageIndicatorCursor\runtime.log
```

The log rotates at roughly 64 KiB to avoid unbounded growth. If `runtime.log` is absent, no contained runtime exception has been recorded in that run.

## Installation

1. Download/unzip a build of this fork.
2. Run `install.cmd`.
3. Start `language-indicator.exe` once if it is not already running.

`install.cmd` creates a shortcut in the current user's Windows Startup folder so the indicator starts automatically after sign-in.

To remove the startup shortcut, run `uninstall.cmd`.

## Windows SmartScreen

Development builds are currently **unsigned**, so Windows SmartScreen can show `Unknown publisher` / `Windows protected your PC` for a newly downloaded EXE. This is a publisher/reputation warning, not a malware verdict from this application.

For a polished public release, the executable should be Authenticode-signed with a trusted code-signing certificate. Rebuilding the EXE changes its hash, so unsigned development builds can trigger SmartScreen again even after an earlier build was allowed. The project intentionally does not attempt to suppress or bypass SmartScreen automatically.

## Releases

After a stable change is merged to `master`, `.github/workflows/release.yml` runs the Windows tests, compiles both executables, packages the runnable files, reads `LanguageIndicator.Version`, and publishes a versioned GitHub Release. Versions containing `-beta` or `-rc` are published as prereleases; stable versions are ordinary releases. If that version already exists, the workflow leaves the existing release untouched.

## Development

The application entry point is `language-indicator.ahk`.

### Tests

Run the AutoHotkey v2 console test suite:

```text
tests\RunTestsConsole.ahk
```

### Compile

With AutoHotkey v2 and Ahk2Exe installed in the standard location:

```text
tools\compile.cmd
```

The compiler writes `language-indicator.exe` in the repository root.

## Relevant implementation

- `lib/CaretIndicator.ahk` follows the active text caret and uses RU/EN mapping.
- `lib/SystemCursorColorIndicator.ahk` generates red/blue outlined copies of standard system cursors and switches the set on a real RU/EN change.
- `lib/CursorIndicator.ahk` implements the optional mouse-following marker, idle timeout, and wake-up on real language changes.
- `lib/runtime/CaretWorkerRuntime.ahk` isolates caret probing in a worker process and supervises it with heartbeat/watchdog recovery.
- `lib/SettingsManager.ahk` loads/saves per-user settings and builds the tray-only settings menus.
- `lib/detection/GetInputLocaleId.ahk` reads the keyboard layout of the active foreground window and tolerates transient focus races.
- `lib/detection/GetLanguageFlagCode.ahk` maps Windows primary language IDs to `ru` / `us` flag assets and retains the last valid supported language through transient helper layouts.
- `lib/image-utils/ImagePainter.ahk` paints click-through overlays with uniform configurable opacity and stale-window recovery.
- `lib/utils/RuntimeLog.ahk` writes throttled runtime diagnostics.

## Limitations

Caret position detection depends on what the target application exposes to Windows. Standard Win32 controls, Chromium/Electron applications and Windows Terminal are supported through multiple detection paths, but some custom-rendered or protected applications may not expose a usable text caret at all. In those applications no caret flag can be shown reliably.

A non-elevated indicator cannot safely inspect caret/UI-accessibility data from an elevated Administrator application because of Windows integrity-level isolation. Elevated PowerShell/Terminal is therefore a known caret-flag limitation. The system-cursor color feature is independent from caret probing and is expected to keep working more broadly, but applications may still replace the pointer with their own custom cursor.

Some applications also use protected or custom-rendered surfaces that Windows screenshot tools cannot capture while the surface is active. That behavior is controlled by the target application/Windows compositor and is separate from this indicator.

In a few highly dynamic editors or chat applications the detected caret rectangle can temporarily be vertically offset, so the flag may follow slightly above the actual text line. This is cosmetic and does not affect language detection.

Because `SetSystemCursor` changes cursor roles for the interactive desktop, force-killing the process can leave the colored cursor set active until Windows reloads the pointer scheme, the app is restarted, or the user signs out. Normal exit/reload restores the captured cursor set.

## Upstream

Original project: `yakunins/language-indicator`.

The upstream project supports per-language styling of the text caret and mouse I-beam cursor, including `.cur`, `.ani`, `.ico`, and `.png` customization. The 0.80 release extends that idea to a broader set of standard Windows cursor roles while preserving their familiar shapes.

## License

MIT, as in the upstream project.
