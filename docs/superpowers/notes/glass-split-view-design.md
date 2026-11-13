# GlassSplitView (SwiftUI `NavigationSplitView`) — design

## API
```dart
GlassSplitView(
  sidebar: ..., content: ... /* optional → two columns */, detail: ...,
  columnVisibility: GlassSplitViewVisibility.automatic, // all / doubleColumn / detailOnly
  onColumnVisibilityChanged: ...,
  preferredCompactColumn: GlassSplitViewColumn.sidebar, // sidebar / content / detail
  onPreferredCompactColumnChanged: ...,
  controller: GlassSplitViewController? , mode: ...
)
```
Both pairs are controlled-or-internal (null callback = internal state), like
SwiftUI bindings. `GlassSplitView.of(context)` returns the controller so
rows in the sidebar call `showColumn(detail)` (compact push) and bars call
`toggleSidebar()`.

## Layout
- **Regular** (width >= `TabSidebarMetrics.regularWidth` = 700): columns side
  by side. Sidebar = floating glass panel, 270 wide, inset 10, radius 26 —
  same metrics as the internal `GlassTabSidebar` sidebar. Content column
  (3-col) is 320 wide, plain page with a hairline separator; detail fills.
  `automatic`/`all` show every column; `doubleColumn` hides the sidebar of
  a 3-column view; `detailOnly` hides sidebar and content. Hiding animates
  (350 ms easeOutCubic, width collapse).
- **Compact**: one column at a time, `preferredCompactColumn`; changing it
  slides the new column in from the end (iOS push) and the old one 1/3 out
  the other way; back = set column to the previous one (`showColumn`).
  Android back button pops to the previous column while not at sidebar.
- Sidebar glass sits over `GlassBackdropSource`-less page; the page keeps
  running under it (detail extends to the screen edge, padded in
  MediaQuery by nothing — SwiftUI floats the sidebar over the detail).
- **Material**: sidebar is a flat `surfaceContainer` column with
  `VerticalDivider`, no inset/radius; compact identical.

## Out of scope
Drag-resize of columns, `NavigationSplitViewStyle.balanced/prominentDetail`,
per-column width `navigationSplitViewColumnWidth` (exposed as
`sidebarWidth`/`contentWidth` params only).

## Stages
1. enums + controller; 2. layout (regular/compact/material); 3. tests;
4. example page + screenshots (iPad Pro 11", iPhone 17 Pro).
