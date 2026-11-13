# Picker palette and date range — SwiftUI parity (iOS 26.4)

Reference scenes: `example/ios/Runner/ReferenceScenes.swift`, launched with
`-controls palettestandalone | palettemenu | multidate`.

## `.pickerStyle(.palette)`

- **Outside a `Menu`** SwiftUI draws it as its segmented control
  (`images/picker-palettestandalone-swiftui.png`). So
  `GlassPickerStyle.palette` is `GlassSegmentedControl`; an item's `icon`
  replaces its label, which stays the semantic label. Material:
  `SegmentedButton`.
- **Inside a `Menu`** it is a row of 17-pt `circle.fill` swatches at a
  42.6-pt pitch, the selected one on a grey 37.5-pt rounded square (corner
  ~8, estimated), under a section header
  (`images/picker-palettemenu-swiftui.png`,
  `images/picker-palettemenu-open-swiftui.png`). Recorded as
  `PickerMetrics.palette*`; **not built yet** — `GlassMenu` has no
  swatch-row item. Follow-up once the menu-sections work lands.

## Date range

- SwiftUI has no range `DatePicker`; the closest is `MultiDatePicker`
  (a month grid, today in blue, no selection by default; discrete days, not
  a range). The package already had `showGlassDateRangePicker` and
  `GlassCalendar.range` (blue end circles, lighter band).
- New `GlassDateRangePicker`: `compact` = grey capsule ("Oct 6 – Oct 9,
  2026") opening the range sheet; `graphical` = `GlassCalendar.range`
  inline; `wheel` is asserted out. `onChanged` gets complete ranges only;
  a lone start lives in the widget state. Material: a button opening
  `showDateRangePicker` (Material has no inline range calendar).
- Discrete multi-day selection (`MultiDatePicker`'s `Set<DateComponents>`)
  is **not** built.

## `hourAndMinute`

`GlassDatePickerMode.hourAndMinute` is a static alias of `time`; the time
capsule and wheel popover were already measured in the date-picker work.

## Not verified

No new simulator capture of the Flutter side (disk was too tight for a
build); parity rests on the reused, previously measured widgets.
