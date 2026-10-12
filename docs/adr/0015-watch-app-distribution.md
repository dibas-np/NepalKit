# How the Watch app reaches users

Date: 2026-10-11
Status: accepted — option C, until users ask for store distribution

## Context

The standalone Watch app shipped in 1.6.0 but has no distribution channel. It is
installed from Xcode with development signing, and the Mac DMG installs only the
macOS app. That has two consequences with dates attached:

- **There is no way to update it.** A calendar data correction cannot reach a
  Watch user. The Samiti's determination of 2084 BS is expected in January to
  February 2027, and if it differs from the provisional row (ADR-0014), Mac
  users get the fix through Sparkle and Watch users get nothing.
- **Current installs stop working.** The development signing certificate expires
  on 2027-09-27 and the provisioning profiles on 2027-10-02
  (`docs/watch/signed-build-refresh-2026-10-03.md`). An app with an expired profile
  no longer launches on the device, so every current install needs a store build
  or a re-signed build before then.

The roadmap held this decision on "whether the Mac app stays Developer-ID-only".
That question and this one are separable: the update-model cost the roadmap
names applies to running two channels *for one product*, and ADR-0009 already
versions the Mac and Watch products on separate tracks.

## Options

**A. The Watch app on the App Store; the Mac app stays Developer ID with
Sparkle.** One channel per product. Costs: an App Store Connect record, a
privacy manifest for the Watch product, a review cycle, and store metadata
and support pages that match the product. The Watch already runs without an
iPhone app, which the store supports for standalone watchOS apps. The store
build must decide how the provisional 2084 row ships (the Mac App Store
readiness spec rules out shipping it behind a warning alone), a decision best
timed with the 2027 attestation.

**B. Both apps on the App Store, and the Mac app keeps Developer ID too.** The
Mac App Store variant in `.scratch/mac-app-store-readiness/spec.md`: no Sparkle in
the store build, opt-in login item, two update models for the Mac app
permanently. The largest cost, and the roadmap's "permanent tax".

**C. The Watch app stays source-built.** No new channel. Before 2027-09-27, and
after every data release, each Watch user rebuilds and re-signs from Xcode.
Lowest cost to the project; in practice the Watch app is then a developer
preview, and README should say so.

## Decision

**C.** The Watch app stays source-built until users ask for a store release.
Store distribution (A) is the first move when they do; nothing here rules it
out, and its costs and timing are recorded above.

## Consequences

- The Watch app is a developer preview. README says it is built from source, and
  that a development-signed install stops launching when its provisioning
  profile expires; rebuilding from Xcode renews it.
- A calendar data correction reaches Watch users only when they rebuild. A data
  release's notes say so.
- The maintainer's own install needs a rebuild before its certificate expires on
  2027-09-27 (profiles 2027-10-02).
- The roadmap lists Watch store distribution as deferred, reopened by a user
  request (a GitHub issue asking for it is enough).
