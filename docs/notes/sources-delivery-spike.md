# Sources delivery spike — recommendation

**The promise, verbatim.** `NepalKit/Strings.swift:221` (declared `:216-221`,
rendered `NepalKit/AboutView.swift:96`): *"Applies to the app code. The bundled
calendar data carries no licence from this project; see SOURCES.md in the
repository."* One render site — but `AboutView.swift:105-113` already shows a
**Source repository** link on the same surface, so it is one click away, a dead
end only for the user who does not click.

**The `LICENSE` precedent is half a precedent.** The plan (`:66-68`) calls it "a
document shipped in the bundle, *opened from the surface*"; only the first half
exists. `AboutView.swift:91-92` renders `metadata.license` — a `String?` — as a
plain row, and `AppMetadata.licenseIdentifier(in:)` (`:81-100`) parses
`"GNU GENERAL PUBLIC LICENSE 3"` out of the document's first eight lines. Nothing
opens it: `grep` for `QLPreview|NSWorkspace|WKWebView|NSTextView|
CFBundleDocumentTypes` over `NepalKit/` hits once, `WindowPresentation.swift:82` —
the popover's own `open()`. **No document-opening machinery exists here.**
Copyable is the shipping and the test: `InfoPlistKeysTests.swift:175-214` asserts
presence at `Contents/Resources/LICENSE`, four content markers, no prepended
notice — gated on `hasBuiltProduct`, comparing *markers*, not byte-identity.

**The split** (`SOURCES.md`: 415 lines, 3,418 words). User-relevant ≈770 —
*The honest summary* (400), *The licence covers the code* (144), *Why 2084 is the
upper bound* (222). Contributor-facing ≈2,650 — *Sources* and its six subsections,
*The cross-check*, *The disputed months*, *One gap in the earlier record*, *2084
was contested*, *What is not a licence*. The user third is too long for a 380pt
footnote; its three facts are not: the table is not independently licensed, 2084
is projected (published through 2083), and the Panchanga Nirnayak Samiti is who
to consult.

**Shapes.** (a) Bundle `SOURCES.md`, add a button that opens it — no precedent to
copy, so it invents a viewer; 20KB of raw Markdown (commit hashes, RSC internals,
dead URLs) in a menu-bar window; a copy that can drift; a licence caveat handed to
users as a document they must open. (b) Say the three facts on the surface, let
the existing link carry the record. (c) Generate a user file from `SOURCES.md` —
(a) plus a build step, same gap.

**Recommendation: (b).** The defect is the dependency, not the missing document.
Make the sentence true where the user already is. Rejected (a): nothing to copy,
raw Markdown is wrong for a 380pt window, and it turns a caveat nobody had to
open into one they must. Rejected (c): (b)'s coverage, more parts.

**The offline, non-GitHub user — the honest weakness.** (b) leaves them three
sentences and nothing to check. That is real. It is exactly the guarantee
`LICENSE` gets from its bundle copy, which exists because GPL *requires* it
(`09-repository-tells-the-truth.md:15-17`), not because a URL sufficed.
**Changed by:** your ruling that the calendar claim deserves the same — then (a),
and the licensing question below is blocking. Or a stable user-relevant number
landing in `SOURCES.md`.

**Drift.** Make the summary assert nothing `SOURCES.md` could contradict — no
counts, hashes, or licence names, only the three standing facts. Then it cannot
go stale. If a number is ever added, one test reads `SOURCES.md` and asserts it.
No second copy, no build step.

**ADR: not required, but one recommended.** `CONTRIBUTING.md:132-134` compels a
record for a change to "a supported-range boundary, the licence, the data
provenance, or a platform requirement". Delivery moves none of the four — the
claims are unchanged, only where they are readable. **The plan's `:99-101`
citation is wrong.** Still, "is documented provenance a user-facing promise or a
contributor-facing artefact?" is a values call no rule compels. `0014` is next
free; I did not draft it, since an ADR stating the answer presupposes the
question being put to you.

**Implementation outline — not implemented.** `NepalKit/Strings.swift`: retarget
`licenseScopeNote`, add the projection caveat (the app names neither 2084 nor the
Samiti anywhere). `AboutView.swift:96` needs no structural change. Test in
`NepalKitTests/` asserting the standing claims still match `SOURCES.md`. Verify:
`./scripts/run-app-tests.sh`.

**Open for the maintainer.** Is a bundled provenance document redistributable?
`SOURCES.md:55` says the GPL "covers the code and this document" and nothing is
vendored (`:213`), so I found no blocker — the call is yours. Does delivery need
an ADR? Should raw Markdown be openable from this app at all?
