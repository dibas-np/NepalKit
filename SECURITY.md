# Security Policy

Supporting documents, so the short answers here have somewhere to point:

| Question | Where the full answer is |
| --- | --- |
| What is in scope, and what is not | [Threat model](docs/threat-model.md) |
| What has actually been reviewed, and what was found | [Security assessment](docs/security-assessment.md) |
| What secrets exist, where they live, how they are rotated | [Secrets policy](docs/secrets-policy.md) |
| What the project depends on, and what happens when one is vulnerable | [Dependencies](docs/dependencies.md) |
| How to check that a release you downloaded is ours | [Release verification](docs/release-verification.md) |

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
before installing anything, and refuses an update feed that carries no signature
at all — and the **sandbox entitlements**, which grant outgoing network access
and Mach lookups for Sparkle's two XPC services. If you find a way to make the
app install an update that fails signature verification, that is the finding that
matters most.

The full analysis, including the actors, the trust boundaries, and each threat
with what stands in front of it, is in
[docs/threat-model.md](docs/threat-model.md). Read it before reporting something
that assumes a network capability the app does not have — the absence of any
network call but the update check is the reason this project's threat model is
short, and it is a claim worth trying to falsify.

## Disclosure

**Where a published advisory lives.** Security advisories for this project are
tracked as GitHub Security Advisories on this repository, so they are readable
without an account:

<https://github.com/dibas-np/NepalKit/security/advisories>

A confirmed issue gets an advisory there **before** it is described publicly
anywhere, and the advisory names the affected versions, how a user can tell
whether they are affected, and what to do. Release notes link to the advisory
when there is one.

**There are no published advisories yet**, because no vulnerability has been
reported. That is the current state, not a policy — this section is where the
first one will appear, and the reporting path below is how it gets there.

**If you want to check a release rather than report one**, the commands and the
expected signing identity are in
[docs/release-verification.md](docs/release-verification.md).

