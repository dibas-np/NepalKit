# Contributing

Issues and pull requests are welcome. For a wrong date, include the date and what the official Nepali Patro says.

## Setup

Xcode 27 or later. Open `NepalKit.xcodeproj` and run the **NepalKit** scheme (or **NepalKitWatch Watch App** for the watch).

Before opening a pull request, run:

```sh
./scripts/check-all.sh
```

It builds the app, runs SwiftLint and every test suite. The Watch suite needs the *Apple Watch SE 3 (40mm)* simulator on watchOS 27.

## Calendar data

Changes to month lengths, the supported range or conversion need evidence, not reasoning. Run `python3 scripts/verify-data-sources.py` and record the source in [SOURCES.md](../SOURCES.md). See [docs/updating-calendar-data.md](../docs/updating-calendar-data.md).

## Style

- `NepalKitCore` is pure Foundation logic; UI and app state live in `NepalKit/`.
- Use the terms in [docs/glossary.md](../docs/glossary.md) (Bikram Sambat, Gregorian, Nepal Time).
- Tests use Swift Testing (`@Test`, `#expect`), not XCTest.
- Comment the why, not the what.
- Explain non-obvious decisions (supported range, licence, platform requirements) in the pull request description.

## Pull requests

Keep each pull request to one change and sign off your commits (`git commit -s`, [DCO](https://developercertificate.org/)). Code under `NepalKitCore/` is MIT; everything else is GPL-3.0-or-later.
