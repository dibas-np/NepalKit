# Security Policy

## Supported versions

Security fixes land on the latest release. There is no long-term-support
branch; the project is young enough that backporting would cost more than it
saves.

| Version | Supported |
| --- | --- |
| latest release (see [CHANGELOG.md](CHANGELOG.md)) | yes |
| anything older | no |

## Reporting a vulnerability

**Please do not open a public issue for a security problem.**

Email **dibas.sigdel@gmail.com** with:

- what the issue is, and what an attacker could do with it
- the version of NepalKit (`About NepalKit` shows it, along with the build
  number in parentheses)
- your macOS version
- steps to reproduce, or a proof of concept

You should get an acknowledgement within a few days. Fixes for confirmed issues
ship in a release with a note describing what changed, without naming the
reporter unless they ask to be credited.

**Please give a reasonable window to fix before disclosing publicly.** A
90-day window is the convention. If a fix is going to take longer — and for a
maintained-in-the-open project it sometimes will — that is fine; just say so
rather than going quiet, and the timeline can be extended on request.

## What is in scope

- The app's code, its sandbox entitlements, and its updater
- The update feed and the EdDSA key handling
- The calendar data pipeline (`verify-data-sources.py`, the pinned sources)

## What is not a vulnerability

These are worth reporting and will be treated as bugs, but they are not
security issues:

- **A wrong date.** Correctness bugs in the calendar table are real bugs; open
  an issue. Month lengths are facts, not code, and a bad transcription is a
  data problem rather than an exploitable one.
- **The calendar data's licence provenance.** This is documented openly in
  [SOURCES.md](SOURCES.md), including the parts that are not clean. Disagreement
  with that documentation is welcome as an issue; it is not a vulnerability.
- Anything requiring a user to already have physical access to an unlocked
  machine.

## Threat model, briefly

NepalKit is a sandboxed, menu-bar-only app that reads a bundled calendar table
and can check for updates over HTTPS. It holds no credentials, sends no
analytics, and stores preferences in its own container.

The parts worth hardening are the **updater** — which verifies an EdDSA signature
before installing anything — and the **sandbox entitlements**, which grant
outgoing network access and Mach lookups for Sparkle's two XPC services. If you
find a way to make the app install an update that fails signature verification,
that is the finding that matters most.

## Disclosure

Security advisories for this project are tracked with GitHub Security
Advisories, and linked from the release notes. The repository is public, so
those advisories can be filed from the repository's own Security tab rather than
by email.
