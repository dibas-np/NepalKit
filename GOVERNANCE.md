# Governance

NepalKit is maintained by one person. This document says so plainly, because a
public repository that implies a process it does not have is worse than one
that admits it is small.

## Who decides

**Dibas Sigdel** (`@dibas-np`) is the maintainer and holds all decision-making
authority: what gets merged, what gets released, and what the project is.

There is no steering committee, no benevolent dictator successor on record, and
no governance model beyond this file.

## What that means in practice

- **Merge decisions** are the maintainer's. A pull request may sit open while
  the maintainer is thinking about whether the change is right.
- **Breaking changes** are the maintainer's call. The supported calendar range
  has been narrowed before, and will be again if the data cannot be
  corroborated — that is a decision about honesty, not about features.
- **Releases** are cut by the maintainer, following the process in the
  [fresh-Mac install procedure](docs/release-evidence/fresh-mac-install-procedure.md)
  and driven by `scripts/package-release.sh`. Neither is in the README: a
  release is a maintainer action over a signed artifact on a machine that has
  never trusted the developer, and that is not something a contributor or an
  install guide needs. The README's [Install](README.md#install) section is what
  a user reads.
- **Licensing** cannot be changed by a majority vote of contributors. GPL-3.0 is
  a deliberate choice made for reasons recorded in
  [SOURCES.md](SOURCES.md), and relicensing is a decision only the copyright
  holder can make.

## Contributing

Everyone else contributes through pull requests, under the
[Developer Certificate of Origin](CONTRIBUTING.md#licensing-of-contributions).
DCO means no rights are assigned away by contributing, and it is chosen over a
CLA specifically so that contributing stays a lightweight act.

## Who gets access, and how it is reviewed

This is the policy for granting access to sensitive resources — merge rights,
the release environment, or the secrets that sit behind it. It is short because
the answer is currently short.

### The rule

**Nobody is granted write access, merge rights, release authority, or access to
a secret until the maintainer has reviewed who they are and confirmed they are
entitled to it. Review happens before the grant, not after.**

"Reviewed" means the maintainer has established a defensible lineage of identity:
they can say how they know this account belongs to the person it claims to
belong to. A GitHub account's display name, avatar, or employer is not evidence.
An association with a known trusted organisation or a prior track record of
merged contributions is.

Access is granted per-person and per-resource, never "to the project". If a
contributor needs to see one thing, they are given that one thing.

### What this means in practice right now

The repository has exactly one principal: `@dibas-np`, the copyright holder and
the only person who has ever had write access. There are no collaborators, no
teams, and no organisation. So the policy currently has nothing to review — which
is precisely why it is written down now rather than when the second person
arrives and the first grant is made without a rule to follow.

GitHub itself enforces part of this. There is no way to add a collaborator
without the repository owner doing it explicitly, so permission assignment is
manual by construction. What GitHub does not enforce is the *review* above.

### The escalation this does not cover

Granting merge rights is not the same as granting a secret, and the second is
much bigger. A merge right lets someone change code that will be signed and
shipped. Access to `HOMEBREW_TAP_DEPLOY_KEY`, the Sparkle EdDSA private key, or
the Apple notarization credentials lets someone do things no pull request review
would catch, because the signing happens off-review.

The rule is the same and the bar is higher:

- **Signing and notarization credentials live in one machine's keychain.** They
  are not shared, not backed up to a repository, and not placed in CI. There is
  currently no path by which a second person could be given one, and adding one
  is a decision that requires writing down what changes — not an onboarding step.
- **The exception is `HOMEBREW_TAP_DEPLOY_KEY`**, which is a GitHub *environment*
  secret in `release`, not a keychain item. It cannot sign anything and cannot
  reach this repository; it exists so a tagged release can bump the Homebrew
  cask, and it is scoped to that one repository. It is the only credential any
  CI job can reach, and only on a `v*` tag pushed by the maintainer.
- **A new maintainer does not inherit signing authority.** It is granted
  deliberately, per credential, after the same review.
- **[`docs/secrets-policy.md`](docs/secrets-policy.md) is the authority** on
  what exists, who can reach it, and how it is rotated.

### The gap worth stating

[OSPS-GV-04.01](docs/security-assessment.md) asks whether collaborators are
reviewed before being granted escalated permissions. The honest answer for this
repository today is: **yes, by the only person who could grant them, and there
are none to review.** That is a real answer, but it is also a thin one, and it
would stop being adequate the moment a second person were added. The
[security assessment](docs/security-assessment.md) records this as finding F3
and says what would close it.

## Becoming more than one person

If the project ever grows contributors who want a say in direction, that
conversation should happen in public and the outcome should be written into
this file. Two things must be decided at that point rather than drifting into
place: who can merge, and who holds the signing keys. Until then, this file is
the honest description.

## Reporting a governance problem

If the maintainer's conduct is the problem, that is a real situation this
document does not solve. The maintainer's own email is not an escalation
path. GitHub's
[community health documentation](https://docs.github.com/en/site-policy/communities)
describes reporting abuse directly to GitHub, which is the appropriate route.
