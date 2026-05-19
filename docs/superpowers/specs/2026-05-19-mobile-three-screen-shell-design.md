# Mobile Three-Screen Shell Design

Date: 2026-05-19
Status: Approved for implementation

## Purpose

Improve the iPhone shell so it behaves like a Bear-style horizontal three-screen workspace:

1. Library/sidebar screen
2. Document list screen
3. Editor screen

The app should open directly on the editor screen by default, so the first visible state is writable content rather than a navigator.

## Visual Direction

The selected direction is the Bear-like model from the visual companion:

- The library/sidebar sits to the left with a darker, compact navigation treatment.
- The document list sits in the middle and shows the active collection's pages.
- The editor sits on the right and is the default screen.
- A sliver or motion relationship should make adjacent screens feel spatially connected when revealing them.

The outline is not part of the three main screens in the first implementation. It remains a right-side editor affordance, presented as a lightweight drawer or overlay from the editor.

## Goals

- Launch iPhone into the selected or first available editable page.
- Preserve immediate typing and initial focus behavior.
- Let users reveal the document list from the editor with a visible back/menu affordance and an edge-safe horizontal gesture.
- Let users reveal the library/sidebar from the document list.
- Keep the page outline available from the editor without making it compete with the three primary screens.
- Reuse current compact collection, page list, page editor, and outline data paths.

## Non-Goals

- Do not change the block editor chrome, TextKit editing surface, block alignment, or storage model.
- Do not refactor the desktop `NavigationSplitView`.
- Do not promote outline into a fourth pager screen in this slice.
- Do not add a full search redesign.
- Do not introduce broad animation or persistence changes beyond the compact shell state needed for navigation.

## Current State

The current compact shell already pushes an initial page on launch and routes through:

- `CompactEditorShell`
- `CompactHomeView`
- `CompactPageListView`
- `CompactCollectionDestination`
- `CompactPageDestination`
- `EditorCanvasView`

The right-side outline already exists as mobile outline drawer behavior inside the editor canvas. This should be kept and visually tuned only if necessary.

## Interaction Model

### Default Launch

On iPhone compact width, launch should resolve the selected page or first available page and show the editor screen as the active screen. The page should be editable immediately, matching the existing "open into writing" behavior.

### Screen Order

The horizontal order is:

1. Library/sidebar
2. Document list
3. Editor

The active index defaults to `3`.

From editor:

- Back/menu button reveals the document list.
- A rightward edge gesture may reveal the document list if it does not interfere with text editing, selection, or block gestures.
- Outline button opens the outline drawer from the right.

From document list:

- Menu button reveals the library/sidebar.
- Selecting a page returns to the editor screen for that page.

From library/sidebar:

- Selecting a collection opens the document list for that collection.
- Selecting a direct collection with a single current target may still route through the document list unless an existing compact rule already opens a page directly.

### Gesture Safety

Gestures must avoid stealing:

- Text insertion and selection
- Block drag and selection
- Mobile formatting toolbar interactions
- Horizontal gestures already used by editor block controls

Prefer edge-only shell gestures first. If conflict is observed, keep button navigation and leave broad swipe gestures out of the first implementation.

## Outline Behavior

The editor keeps a right-side outline affordance:

- The outline opens as a drawer or overlay.
- Selecting an outline item closes the drawer and scrolls/focuses the target heading.
- Empty outline state remains supported.
- The drawer should not become the default rightmost screen in this slice.

## Implementation Shape

Prefer a small compact-shell change:

- Add a compact shell state/model for the visible screen.
- Reuse existing compact list and collection views where possible.
- Keep editor routing through `CompactPageDestination` and `EditorCanvasView`.
- Keep page navigation and pending compact navigation behavior in `WorkspaceViewModel`.
- Add accessibility identifiers for the new shell surfaces and controls so UI tests can target them.

Do not touch block chrome constants or list-row alignment rules.

## Testing

Add tests before production changes:

- Unit/model test for the compact shell screen order and default active screen.
- Unit/model test that selecting a collection moves from library/sidebar to document list.
- UI test or focused compact-shell test proving iPhone launch still exposes an editable text block immediately.
- UI test or focused compact-shell test proving the document list can be revealed from the editor.
- Regression check that the mobile outline drawer still opens and closes from the editor.

Run focused editor tests plus an iOS build. If simulator/device UI automation is available, run the relevant `EditorIOSUITests`.

## Acceptance Criteria

- iPhone launch opens on an editable editor screen by default.
- Document list and library/sidebar are reachable without leaving compact mode.
- Selecting a page from the document list returns to the editor.
- Outline remains available from the editor and does not replace the three-screen model.
- Existing mobile keyboard toolbar and immediate typing behavior still work.
