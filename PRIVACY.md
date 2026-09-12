# Privacy policy

Language Indicator Cursor is a local Windows desktop utility. It does not include telemetry, analytics, advertising, account login, cloud synchronization, or background network communication.

**This program will not transfer any information to other networked systems unless specifically requested by the user or the person installing or operating it.**

## Local data

The application may create the following files under `%APPDATA%\LanguageIndicatorCursor`:

- `settings.ini` for user-selected indicator settings;
- `runtime.log` for throttled local diagnostic messages when a contained runtime error occurs;
- `runtime.old.log` as a rotated previous diagnostic log.

These files stay on the local computer unless the user explicitly chooses to share them for support or debugging.

## Runtime access

To provide its function, the application reads local Windows state such as the active keyboard layout, foreground/focused window information, mouse position, and text-caret position exposed by Windows accessibility/input APIs. This information is used locally to render the language indicators and is not transmitted by the application.

## Downloads and updates

Downloading releases from GitHub, viewing project pages, or obtaining updates is initiated by the user and is subject to the privacy policies of the service used for that download. The application itself does not automatically send usage data to GitHub or to the project maintainer.

## Code signing

If SignPath Foundation code signing is approved, signing is performed during the release build process. The installed application does not communicate with SignPath at runtime.
