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
