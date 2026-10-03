# NepalKit Mac App Store readiness

Status: draft planning handoff
Date: 2026-10-03

## Outcome

Prepare a Mac App Store variant that preserves NepalKit's menu-bar Today,
Nepal Time, converter, display settings and Shortcuts while excluding the
external updater. Keep the Developer ID release channel working. Establish
truthful privacy, calendar and support information and a reviewable archive.

This document and its tickets are planning deliverables. They do not authorize
implementation, publishing pages, uploads, submission or release operations.
The [verified audit](audit.md) records evidence and corrections to the supplied
report. Ticket statuses are draft because implementation choices and external
evidence are still outstanding.

## Requirements

- A store product contains no Sparkle executable dependency, helper services,
  updater UI, updater keys or updater-specific entitlements. A compilation
  condition alone is insufficient if the package remains linked or embedded.
- Store launch performs no automatic login-item registration. Explicit opt-in
  controls it; existing system registrations are reflected rather than revoked.
- The built product contains a valid app-owned privacy manifest describing
  audited use. Privacy policy, support links and metadata match that product.
- The production dataset follows ADR-0001. Temporary 2084 projection and its
  tests remain available for development until an approved resolution. The
  store cannot ship that row merely by adding a warning.
- Calendar-data and code/dependency distribution rights have a recorded outcome.
- The second-resolution popover clock runs only while visible, refreshes on
  opening, and cancels work on closing. The independent menu-bar date refresh
  continues. Energy claims require measurements.
- Reviewer instructions describe the actual menu-bar entry point, Settings
  gear, focused shortcuts, supported range and privacy behavior.
- Store readiness is demonstrated by archive inspection and validation evidence,
  not SDK presence, source greps or a successful ordinary development build.

## Decisions to settle in tickets

01 chooses target/configuration isolation, identifiers and channel coexistence.
02 chooses whether consent-only login becomes common to both channels or stays
store-specific. 04 needs final hosted URLs and approved public copy. 05 and 06
require dataset-policy and rights evidence. Recommendations in tickets are not
new ADRs. Any channel-specific refinement of ADR-0008/0012 must be recorded;
ADR-0001 and ADR-0004 are preserved.

## Gates

| Gate | Required evidence |
| --- | --- |
| Planning | Audit and eight draft tickets with dependencies |
| Implementation verification | Both channels build; strict lint and relevant logic/artifact checks pass |
| Store candidate | Dataset policy and rights cleared; privacy/support URLs live; store signature and archive inspected |
| Submission preparation | Current toolchain requirements, native runtime smoke checks, metadata and reviewer notes recorded |
| Upload/review | Separate authorized operation; record validation result and reviewer outcome when performed |

Ticket 07 is a confirmed lifecycle improvement, not an independently proven
store rejection. Ticket 08 must explicitly decide whether its measured result
is a submission blocker. Watch packaging, Watch distribution, pricing, IAP,
accounts and changing the shared dataset policy are outside this effort.
