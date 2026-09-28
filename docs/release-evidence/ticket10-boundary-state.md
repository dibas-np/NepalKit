# Ticket 10 — range-boundary state, captured in the real application

Captured 28 September 2026 from a Release build of the real application,
on the throwaway branch `ticket10-boundary-capture`, which was deleted
afterwards. The clock was overridden at the injection point; the dataset
was not touched, and no launch argument, environment variable or debug
hook exists in the shipped binary.

The second display's menu bar sits at y = -98 rather than y = 0, so the
status item reports a negative y and looks off-screen. It is not. The
popover was opened by clicking the position the accessibility API
reports, which is why it could be captured at all.

The trees below were captured before Screen Recording permission was
granted. Pixel captures of the same two states were taken afterwards and
are in `screenshots/`, and they agree with the trees. The one thing only
a pixel can show is the menu bar's **drawn** compact marker, which the tree
cannot report because the accessibility label replaces the drawn string:
the tree says "date unavailable, calendar data ends 12 April 2028" and the
screen says `n/a`. Both are correct, and they are different on purpose.

## Captured instant: 13 April 2028, 12:00 Nepal Time

### Menu bar
```
AXMenuBarItem: NepalKit, date unavailable, calendar data ends 12 April 2028
```

### Popover
```
AXStaticText: Today
AXStaticText: Bikram Sambat date unavailable. Supported through 2084 BS
AXStaticText: 13 April 2028, बिही
AXStaticText: Nepal Time: 12:00:00
AXStaticText: Local: 12:00:00
AXHeading: Converter
AXStaticText: Year
AXPopUpButton: 2084
AXStaticText: Month
AXPopUpButton: चैत
AXStaticText: Day
AXPopUpButton: 30
AXStaticText: Result: 12 April 2028, बुध
AXButton: Settings…
AXButton: About NepalKit
AXButton: Quit NepalKit
```
Process alive after capture: yes, no crash.

## Captured instant: 13 April 2035, 12:00 Nepal Time

### Menu bar
```
AXMenuBarItem: NepalKit, date unavailable, calendar data ends 12 April 2028
```

### Popover
```
AXStaticText: Today
AXStaticText: Bikram Sambat date unavailable. Supported through 2084 BS
AXStaticText: 13 April 2035, शुक्र
AXStaticText: Nepal Time: 12:00:00
AXStaticText: Local: 12:00:00
AXHeading: Converter
AXStaticText: Year
AXPopUpButton: 2084
AXStaticText: Month
AXPopUpButton: चैत
AXStaticText: Day
AXPopUpButton: 30
AXStaticText: Result: 12 April 2028, बुध
AXButton: Settings…
AXButton: About NepalKit
AXButton: Quit NepalKit
```
Process alive after capture: yes, no crash.

