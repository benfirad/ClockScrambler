# Contributing to ClockScrambler

Thanks for helping improve ClockScrambler.

## Reporting a bug

Please include:

- macOS version
- Mac and display model
- Display scaling
- Digital or analog system clock
- ClockScrambler display and position settings
- A cropped screenshot of the menu bar
- Clear reproduction steps

Do not include private notifications, account details, or unrelated desktop
content in screenshots.

## Development

1. Install Xcode and XcodeGen.
2. Run `xcodegen generate`.
3. Open `ClockScrambler.xcodeproj`.
4. Build the `ClockScrambler` scheme.

Before opening a pull request, verify a Release build:

```bash
xcodebuild \
  -project ClockScrambler.xcodeproj \
  -scheme ClockScrambler \
  -configuration Release \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Keep changes focused and explain their user-visible impact in the pull request.
