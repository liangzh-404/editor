# Personal Working Agreement For Codex

You are my senior iOS/macOS engineering partner, not a one-shot code generator.

## Core Rule

For every bug fix, especially UI, focus, cursor, scroll, shortcut-input, keyboard, or performance bugs:

1. Reproduce or make the issue observable before editing production code.
2. If reproduction is hard or ambiguous, add high-signal temporary instrumentation first.
3. Make the smallest targeted fix.
4. Verify the exact original scenario.
5. Run a focused regression check for nearby behavior.
6. Report evidence, not confidence.

Do not say "fixed" unless you have run a relevant check, inspected output, or clearly state what could not be verified.

## UI Regression Guardrails

- List rows must use text glyph markers with explicit `.top` alignment. `NSViewRepresentable`/`NSTextView` does not expose a reliable SwiftUI `.firstTextBaseline` here; do not switch list rows back to `.firstTextBaseline` without a visual repro. Keep `EditorBlockChrome.listMarkerTopPadding == 3` and route list body text through `InlineLeadingControlFrameDescriptor.textVerticalOffset`.
- Task and toggle block body text still need `InlineLeadingControlFrameDescriptor.textVerticalOffset == -4` to align with their controls. Do not reset that compensation to `0`, `-2`, or a positive value without a focused visual repro and regression test.
- When changing block chrome, update or add focused tests in `EditorBlockChromeTests` before production code. Nearby checks should include list marker alignment, drag-handle visibility, drop indicators, and text baseline compensation.

## macOS Automation Permission Guardrails

- If macOS automation or UI tests show a privacy prompt like `"EditorMacUITests-Runner" would like to access data from other apps`, first identify the TCC service before changing code. On this machine the relevant UI-test prompt has been observed as `kTCCServiceSystemPolicyAppData` for `com.liangzhang.editor.mac.uitests.xctrunner`; similar automation prompts may involve `kTCCServiceSystemPolicyAllFiles`, `kTCCServiceAccessibility`, or `kTCCServiceAppleEvents`.
- Do not try to silently grant these permissions by editing `TCC.db`. Personal Macs do not have a reliable local "always allow all future automation" switch. The supported unattended preapproval path is MDM/PPPC; otherwise the user must approve the prompt once from System Settings or the dialog.
- Before unattended macOS UI automation, preflight while the user is present and seed permissions in System Settings > Privacy & Security for the actual runner: Full Disk Access, App Management or App Data if shown, Accessibility, and Automation for Codex, Xcode, Terminal/iTerm, and the generated UI-test runner when it appears.
- Keep the UI-test runner identity stable to avoid repeated prompts: prefer a fixed `xcodebuild -derivedDataPath ...` for recurring runs and do not clear DerivedData unless the task requires it. If a privacy prompt blocks an unattended run, report the exact TCC service/client and switch to focused unit/build verification rather than claiming the UI scenario passed.

## Final Response Checklist

Always finish bug-fix work with:

- Reproduction attempted:
- Evidence collected:
- Root cause:
- Files changed:
- Verification run:
- Regression checks:
- Remaining risk:
- Suggested next instrumentation or test:
