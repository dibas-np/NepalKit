# Contributing

Issues and pull requests are welcome. To report a wrong date, include the date and what the official Nepali Patro says for it.

## Build and test

You need Xcode 27 or later. Open `NepalKit.xcodeproj` and run the **NepalKit** scheme. For the Watch app, run the **NepalKitWatch Watch App** scheme.

Before you open a pull request, run:

```sh
./scripts/check-all.sh
```

The script builds the app and runs SwiftLint, the Swift test suites, and the Python script tests. Its last step runs the Watch tests on the Apple Watch SE 3 (40mm) simulator with watchOS 27.0. CI runs the appcast and signing-key tests on Linux, because they need OpenSSL 3.

## Change the calendar data

A change to month lengths, the supported range, or conversion needs a published source, not an argument. Run `python3 scripts/verify-data-sources.py`, and record the source in [SOURCES.md](../SOURCES.md). For the full steps, see [Updating the calendar data](../docs/updating-calendar-data.md).

## Follow the code style

- `NepalKitCore` holds the calendar logic and depends only on Foundation. UI and app state live in `NepalKit/`.
- Use the terms in the [glossary](../docs/glossary.md), such as Bikram Sambat, Gregorian, and Nepal Time.
- Write tests with Swift Testing (`@Test`, `#expect`), not XCTest.
- Write comments that say why the code does something, not what it does.
- In the pull request description, explain any decision a reviewer can't see from the code, such as a change to the supported range, the license, or the platform requirements.

## Open a pull request

Keep each pull request to one change. Sign off each commit with `git commit -s` to certify the [Developer Certificate of Origin](https://developercertificate.org/). A contribution is licensed like the files it changes. See the [license section of the README](../README.md#license).
