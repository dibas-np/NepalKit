# The Best Practices badge entry

NepalKit has an [OpenSSF Best Practices](https://bestpractices.dev/) project
entry, [project 15209](https://www.bestpractices.dev/en/projects/15209). This
document explains how the answers in [`.bestpractices.json`](../.bestpractices.json)
relate to that entry, and what to do when one of them stops being true.

## Why there are two places

The badge lives on a website, and the answers to it are claims about this
repository. A claim that lives only on a website cannot be reviewed in a pull
request, cannot be diffed, and cannot be reverted. So the answers live here, in
version control, and the website is a viewer over them.

That split is also what makes the answers trustworthy. Every justification in the
file points at a file in this repository — a ruleset, a workflow, a policy
document — rather than asserting a fact about itself. If the claim is wrong, the
pointer is wrong too, and that shows up in a review.

## What the file is

`.bestpractices.json` at the repository root, or `.project.d/bestpractices.json`.
The badge reads it and proposes the values into the project edit form. A human
still reviews and saves; the file never writes to the entry by itself.

```json
"osps_br_07_02_status": "Met",
"osps_br_07_02_justification": "docs/secrets-policy.md inventories every credential..."
```

Field names are the lowercase underscore form — `osps_ac_01_01_status`, not
`OSPS-AC-01.01_status`. The uppercase dotted form appears in the entry's JSON
export and in some UI labels; the file uses the lowercase one.

Alongside the criteria, the file proposes the four non-criteria fields: `name`,
`description`, `license`, and `implementation_languages`.

## What `?` means here, and where it does not

**In this file, `?` or `"unknown"` means "I don't know the answer", and the badge
ignores it entirely.** That is deliberate: it makes the file safe to copy from
another project that has placeholders left in it.

**In a proposal URL, `?` means the opposite** — it resets the field to unknown.
The two mechanisms disagree on purpose: a proposal URL represents an explicit
human action, while a JSON file represents tool output. Upstream's own wording
is "explicit human actions through a URL" against "automated tool outputs",
which is worth borrowing because the distinction is about who acted, not about
what a string is.

So a `?` here is never an error, and `scripts/verify-bestpractices-json.py` does
not flag it.

## The four statuses

| Value | Meaning |
| --- | --- |
| `Met` | The criterion holds. The justification must point at the evidence |
| `Unmet` | The criterion does not hold, and that is the honest answer |
| `N/A` | The criterion does not apply. Its own justification is required |
| `?` / `unknown` | No answer. Ignored by the badge |

`Unmet` and `N/A` are not failures of this file. They are the answers that keep
the entry honest, and removing them to raise a percentage would make the entry a
worse description of the project.

## Current standing

191 criteria across the two series: **145 Met, 7 N/A, 39 Unmet**.

| Series | Criteria | Met | N/A | Unmet |
| --- | --- | --- | --- | --- |
| Baseline (OSPS) | 64 | 58 | 3 | 3 |
| Metal | 127 | 87 | 4 | 36 |
| **Total** | **191** | **145** | **7** | **39** |

The Metal series carries far more `Unmet`, and the reason is mostly age rather
than substance: eleven of them need a *record* - a closed bug report, a fixed
vulnerability, a prompt warning fix - and a project a week old has not had the
opportunity to produce one. Several will change on their own.

### The six Baseline answers that are not `Met`

The Baseline non-`Met` answers, and why, are also in
`docs/security-assessment.md` as findings F1 to F8 and in the justifications
themselves. In short:

| Criterion | Answer | Reason |
| --- | --- | --- |
| `osps_ac_01_01` | N/A | GitHub has no MFA enforcement for a repository owned by a user account |
| `osps_qa_04_01` | N/A | Single repository |
| `osps_qa_04_02` | N/A | Single repository |
| `osps_vm_06_02` | Unmet | CodeQL and SonarCloud evaluate every change; neither blocks a finding. Finding F8 |
| `osps_qa_02_02` | Unmet | No SBOM is generated or shipped |
| `osps_vm_04_02` | Unmet | No VEX document |

## The two series

The badge has two independent ladders and this file answers both.

| Series | Levels | Criteria file | Field names |
| --- | --- | --- | --- |
| Baseline (OSPS) | `baseline-1`, `baseline-2`, `baseline-3` | `criteria/baseline_criteria.yml` | `osps_<category>_<nn>_<nn>` |
| Metal | `passing`, `silver`, `gold` | `criteria/criteria.yml` | short names, e.g. `bus_factor` |

Two details that cost a wrong answer when this file was written:

- **Two Metal fields are not lower_snake_case.** The badge spells them
  `require_2FA` and `secure_2FA`, capitals included. A shape check that demanded
  lower_snake_case rejected both, which would have kept the two most
  security-relevant Metal answers out of the file. The verifier's pinned sets
  are the authority for names; the shape check is only a typo-catcher.
- **The series must not be crossed.** A field named `osps_*` that is not a
  Baseline criterion, or a Metal field carrying an `osps_` prefix, is silently
  dropped by the badge. The verifier checks for both directions.

## Changing an answer

1. Edit `.bestpractices.json`. Every criterion needs both a `_status` and a
   `_justification`, and the justification must survive the question *"what would
   prove this wrong?"*
2. Run the gate:

   ```sh
   python3 scripts/verify-bestpractices-json.py
   ```

   It is gate 11 of `scripts/check-all.sh`, and gate 10 runs the verifier's own
   suite. It takes **no arguments**: it always checks the file above, which keeps
   a path-injection surface out of a script an agent may be asked to run.

   It checks two things, and the second is the one that matters most:

   - **Structure** — JSON validity, field names, statuses, and the
     status/justification pairing.
   - **Completeness** — all 191 criterion names are pinned in the verifier
     (64 Baseline and 127 Metal) and compared against the file. Deleting *both* halves of one answer leaves no
     unmatched pair for a structural check to notice, and the badge would then
     omit that answer with no error anywhere. Only a pinned set catches it.

   It deliberately does not check whether an answer is *true*, because nothing
   in this repository can know that.
3. Ask the maintainer to re-trigger the badge's automation. Editing the file does
   not by itself re-run the analysis; that needs **Save (and continue) 🤖** on
   the project edit form.

## When does an answer go stale

A status that has quietly stopped being true is worse than a missing one, because
the entry keeps claiming it. The ones most likely to rot, and what invalidates
each:

| Answer | Invalidated by |
| --- | --- |
| `osps_ac_03_01`, `osps_ac_03_02` | The `main` ruleset losing its `pull_request` or `deletion` rule |
| `osps_le_01_01` | `dco.yml` being deleted, or ceasing to be a required check |
| `osps_vm_05_03` | `dependency-review.yml` being deleted, or ceasing to be required |
| `osps_vm_06_02` | A `code_scanning` rule being added to the ruleset — which would make this answer wrong in the project's favour |
| `osps_qa_07_01` | A second approver being added, or the bypass actor being removed |
| `osps_br_01_03` | Any `pull_request` workflow gaining a `secrets.` reference |
| `osps_vm_04_01` | The first security advisory being published |

The first two rows are the ones a well-meaning change can silently invalidate:
relaxing a ruleset is a small diff that makes a `Met` untrue without touching a
line of this file. That is why the justifications name the ruleset rather than
saying "branch protection is enabled".

The Metal series has its own version of the same hazard, and two rows are worth
calling out because CI configuration invalidates them:

| Metal answer | Invalidated by |
| --- | --- |
| `code_review_standards`, `two_person_review` | The `main` ruleset losing its `pull_request` rule |
| `hardening` | `ENABLE_HARDENED_RUNTIME` being turned off, or `package-release.sh` ceasing to check it |
| `signed_releases` | Notarization or the appcast Ed25519 signature being dropped |
| `version_tags_signed` | Release tags becoming signed - which would make this `Unmet` wrong in the project's favour |
| `static_analysis_fixed` | Code scanning being disabled, or alerts being closed by suppression rather than by fixing them |

## Checking the criterion names against upstream

The gate cannot check that `osps_br_07_02` is a real criterion, because that
needs the badge's own criteria file and a network request. To re-check:

```sh
curl -sS https://raw.githubusercontent.com/ossf/best-practices-badge/main/criteria/baseline_criteria.yml
curl -sS https://raw.githubusercontent.com/ossf/best-practices-badge/main/criteria/criteria.yml
```

Compare each key set against the matching `_status` keys here. All 64 Baseline
criteria were verified against the `2026-08-28` baseline, and all 127 Metal
questions against `criteria/criteria.yml`, when this file was written.

The Metal file nests three levels deep - level, then group, then criterion, then
question - and the **question** is the field name. A criterion name like
"Project oversight" is a heading; `bus_factor` underneath it is the field.

A name the badge does not recognise is **silently ignored** — no error, no
warning, the answer just never appears. That is the failure this check exists to
catch by hand.
