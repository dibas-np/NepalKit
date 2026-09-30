# Calendar trigger spike — recommendation

**The trigger, as an observable condition.** The dataset ends at 2084 BS =
2028-04-12 (`CONTEXT.md:44`) and 2084 is *projected* (`README.md:52`). The Nepal
Panchanga Nirnayak Samiti publishes an official determination for 2084 BS,
announced in prose on `npns.gov.np`, expected around Magh 2083 BS —
January–February 2027 (`SOURCES.md:322-327`, `spec.md:104-107`). The remedy is
already a written monthly check (`.scratch/dataset-2085/spec.md:100-119`);
nothing enforces it.

**No machine-readable signal exists — and the sources that have one carry no
news.** No code in this repository fetches `npns.gov.np`. Checked live today: all
four pinned tables already publish 2085, `go-bs` reaches 2087, and KMC already
serves 2085, answering 2086 with a silent fallback to 2085 Chaitra. All sit past
the attested year, which is exactly what a projection does
(`docs/release-evidence/dataset-extension-procedure.md:183-186`). A gate on any of
them is green today and forever — the "green job that checks nothing" this spike
exists to avoid.

**Recommendation: one more job on the clock that already runs.** Add a third job
to `.github/workflows/data-sources.yml`, on its existing monthly cron (`:22`),
with the same `if:` as `sparkle-pin-freshness` (`:53`). It reads a `last_checked:`
date committed beside the runbook and fails when it is over 35 days old, gated on
`max(shipped_table()) < 2085` so it silences itself when the extension ships. No
new permissions (`contents: read`, `:26-27`), no new script, no scraper. Rejected:
a dated *test* runs only on push/PR, turning a calendar obligation into a push
obligation; an issue-opening job needs `issues: write`, widening a read-only
gate's token for a notice the red run already delivers
(`docs/adr/0012-sparkle-version-pin.md:259-268`).

**Two assertions, two messages, one check.** Neither re-attestation (2084) nor
detection (2085) is assertable, so they survive as failure text: the first points
at the procedure's Branch A, the second says agreement is not attestation
(`scripts/verify-candidate-year.py:222-224`) and 2085 waits for the Samiti.

**The counter-argument.** A date check catches a lapse, not a missed notice, and
stays red until someone bumps a file — a second memory obligation. It is still
cheaper than the one it replaces: a red run on a public repository cannot be
missed like a date in a file.

**Update channel.** The extension is a data release (procedure §3g), so it assumes
a release train, and there is one (1.1, 1.2, 1.3.0 in two days,
`CHANGELOG.md:7,21,30`). Upstream, two things are open today: `python3
scripts/verify-appcast.py appcast.xml` exits 1 because the feed is unsigned, and
`docs/adr/0012-sparkle-version-pin.md:169-190` has two unticked custody boxes.
Unsigned, the fix cannot ship at all.

**Falsified by** a machine-readable Samiti almanac, which supersedes this note
outright — or by this job going red twice unread: delete it, do not iterate.

**Not decided here:** who owns the monthly check. The untracked
`.scratch/follow-up-decisions/decisions.md` was read and contradicts none of this.
No ADR is needed: no range, licence, provenance or platform requirement moves
(`CONTRIBUTING.md:132-135`).
