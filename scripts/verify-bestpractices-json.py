#!/usr/bin/env python3
"""Structural check on .bestpractices.json.

Run: python3 scripts/verify-bestpractices-json.py

The OpenSSF Best Practices automation reads this file from the repository root
and proposes its values into the project edit form. That makes it a machine-read
input to a third party, which is the same shape as every other file this
repository gates - and the reason it is checked here is the reason the other
gates exist: a gate that reports green while something is wrong teaches people
to ignore green.

Two failure modes it exists to catch:

1. **A malformed field.** A mistyped status, a status without its justification,
   a blanked justification, an unknown key. These are caught structurally, and
   they are what a careless edit produces.
2. **A silently missing criterion.** If both ``osps_x_status`` and
   ``osps_x_justification`` are deleted, every structural check still passes -
   there is no unmatched pair, because neither half is there. The badge would
   then omit that answer with no error anywhere. So the criterion set is pinned
   in EXPECTED_CRITERIA and compared, which is the only way to notice an absence.

What it deliberately does NOT check:

* **Whether an answer is TRUE.** Nothing here can know that. That is the whole
  point of the automation-proposals design: the values are proposals a human
  reviews, and the repository documents are the evidence. A status that has
  stopped being true is fixed by editing this file, not by loosening this check.

* **Whether each criterion name is a real one upstream.** That needs the badge's
  criteria YAML, which means fetching it, and check-all.sh is offline by design
  - the same reason verify-data-sources.py is not in that list. To re-check the
  names against upstream, fetch criteria/baseline_criteria.yml from
  github.com/ossf/best-practices-badge and diff the key set. That was done when
  this file was written, and it is recorded in docs/bestpractices-entry.md.

Note on ``?``: in .bestpractices.json a ``?`` means "I don't know the answer" and
the badge ignores it entirely, so it is safe to leave placeholders in place. It
is NOT the same as the query-string proposal mechanism, where ``?`` resets a
field to unknown. A ``?`` here is never an error.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
ENTRY = REPO_ROOT / ".bestpractices.json"

# Fields the badge accepts in any section, from docs/automation-proposals.md.
NON_CRITERIA_FIELDS = {
    "name",
    "description",
    "license",
    "implementation_languages",
}

VALID_STATUSES = {"Met", "N/A", "Unmet", "?", "unknown"}
STATUS_SUFFIX = "_status"
JUSTIFICATION_SUFFIX = "_justification"

# A typo-catcher, not the authority - the pinned sets are. It only has to reject
# things that cannot be a field name at all.
#
# Case-insensitive on the first character class because two real Metal fields
# are not lower_snake_case: the badge entry spells them `require_2FA` and
# `secure_2FA`, capitals included. An earlier version of this check demanded
# lower_snake_case and rejected both, which would have kept the two most
# security-relevant answers out of the file the badge reads. The pinned sets are
# what make that safe to allow: a name not in them is caught by completeness.
CRITERION_NAME = re.compile(r"^[A-Za-z][A-Za-z0-9_]*$")

# The criterion set this repository answers, pinned so that deleting both halves
# of one answer is detectable. Sorted; one per line; regenerate from the entry
# file when a criterion is deliberately added or removed, and say so in the
# commit that does it.
# The criterion set this repository answers, pinned so that deleting both halves
# of one answer is detectable. Two series, kept apart because they are separate
# badge ladders with separate criteria files: the OSPS Baseline series in
# criteria/baseline_criteria.yml, and the Metal series in criteria/criteria.yml.
# A Metal field that looked like an OSPS one, or the reverse, would be silently
# dropped by the badge, so the two lists do not overlap and neither does the
# completeness check.
#
# Regenerate from the entry file when a criterion is deliberately added or
# removed, and say so in the commit that does it.
BASELINE_CRITERIA = frozenset(
    {
    "osps_ac_01_01",
    "osps_ac_02_01",
    "osps_ac_03_01",
    "osps_ac_03_02",
    "osps_ac_04_01",
    "osps_ac_04_02",
    "osps_br_01_01",
    "osps_br_01_03",
    "osps_br_01_04",
    "osps_br_02_01",
    "osps_br_02_02",
    "osps_br_03_01",
    "osps_br_03_02",
    "osps_br_04_01",
    "osps_br_05_01",
    "osps_br_06_01",
    "osps_br_07_01",
    "osps_br_07_02",
    "osps_do_01_01",
    "osps_do_02_01",
    "osps_do_03_01",
    "osps_do_03_02",
    "osps_do_04_01",
    "osps_do_05_01",
    "osps_do_06_01",
    "osps_do_07_01",
    "osps_gv_01_01",
    "osps_gv_01_02",
    "osps_gv_02_01",
    "osps_gv_03_01",
    "osps_gv_03_02",
    "osps_gv_04_01",
    "osps_le_01_01",
    "osps_le_02_01",
    "osps_le_02_02",
    "osps_le_03_01",
    "osps_le_03_02",
    "osps_qa_01_01",
    "osps_qa_01_02",
    "osps_qa_02_01",
    "osps_qa_02_02",
    "osps_qa_03_01",
    "osps_qa_04_01",
    "osps_qa_04_02",
    "osps_qa_05_01",
    "osps_qa_05_02",
    "osps_qa_06_01",
    "osps_qa_06_02",
    "osps_qa_06_03",
    "osps_qa_07_01",
    "osps_sa_01_01",
    "osps_sa_02_01",
    "osps_sa_03_01",
    "osps_sa_03_02",
    "osps_vm_01_01",
    "osps_vm_02_01",
    "osps_vm_03_01",
    "osps_vm_04_01",
    "osps_vm_04_02",
    "osps_vm_05_01",
    "osps_vm_05_02",
    "osps_vm_05_03",
    "osps_vm_06_01",
    "osps_vm_06_02",
    }
)

METAL_CRITERIA = frozenset(
    {
    "access_continuity",
    "accessibility_best_practices",
    "assurance_case",
    "automated_integration_testing",
    "build",
    "build_common_tools",
    "build_floss_tools",
    "build_non_recursive",
    "build_preserve_debug",
    "build_repeatable",
    "build_reproducible",
    "build_standard_variables",
    "bus_factor",
    "code_of_conduct",
    "code_review_standards",
    "coding_standards",
    "coding_standards_enforced",
    "contribution",
    "contribution_requirements",
    "contributors_unassociated",
    "copyright_per_file",
    "crypto_algorithm_agility",
    "crypto_call",
    "crypto_certificate_verification",
    "crypto_credential_agility",
    "crypto_floss",
    "crypto_keylength",
    "crypto_password_storage",
    "crypto_pfs",
    "crypto_published",
    "crypto_random",
    "crypto_tls12",
    "crypto_used_network",
    "crypto_verification_private",
    "crypto_weaknesses",
    "crypto_working",
    "dco",
    "delivery_mitm",
    "delivery_unsigned",
    "dependency_monitoring",
    "description_good",
    "discussion",
    "documentation_achievements",
    "documentation_architecture",
    "documentation_basics",
    "documentation_current",
    "documentation_interface",
    "documentation_quick_start",
    "documentation_roadmap",
    "documentation_security",
    "dynamic_analysis",
    "dynamic_analysis_enable_assertions",
    "dynamic_analysis_fixed",
    "dynamic_analysis_unsafe",
    "english",
    "enhancement_responses",
    "external_dependencies",
    "floss_license",
    "floss_license_osi",
    "governance",
    "hardened_site",
    "hardening",
    "implement_secure_design",
    "input_validation",
    "installation_common",
    "installation_development_quick",
    "installation_standard_variables",
    "interact",
    "interfaces_current",
    "internationalization",
    "know_common_errors",
    "know_secure_design",
    "license_location",
    "license_per_file",
    "maintained",
    "maintenance_or_update",
    "no_leaked_credentials",
    "regression_tests_added50",
    "release_notes",
    "release_notes_vulns",
    "repo_distributed",
    "repo_interim",
    "repo_public",
    "repo_track",
    "report_archive",
    "report_process",
    "report_responses",
    "report_tracker",
    "require_2FA",
    "roles_responsibilities",
    "secure_2FA",
    "security_review",
    "signed_releases",
    "sites_https",
    "sites_password_security",
    "small_tasks",
    "static_analysis",
    "static_analysis_common_vulnerabilities",
    "static_analysis_fixed",
    "static_analysis_often",
    "test",
    "test_branch_coverage80",
    "test_continuous_integration",
    "test_invocation",
    "test_most",
    "test_policy",
    "test_policy_mandated",
    "test_statement_coverage80",
    "test_statement_coverage90",
    "tests_are_added",
    "tests_documented_added",
    "two_person_review",
    "updateable_reused_components",
    "version_semver",
    "version_tags",
    "version_tags_signed",
    "version_unique",
    "vulnerabilities_critical_fixed",
    "vulnerabilities_fixed_60_days",
    "vulnerability_report_credit",
    "vulnerability_report_private",
    "vulnerability_report_process",
    "vulnerability_report_response",
    "vulnerability_response_process",
    "warnings",
    "warnings_fixed",
    "warnings_strict",
    }
)

EXPECTED_CRITERIA = BASELINE_CRITERIA | METAL_CRITERIA

assert len(BASELINE_CRITERIA) == 64, "the pinned Baseline set drifted from 64"
assert len(METAL_CRITERIA) == 127, "the pinned Metal set drifted from 127"
assert not (BASELINE_CRITERIA & METAL_CRITERIA), "the two pinned series overlap"


def check(path: Path, *, require_complete: bool = False) -> tuple[list[str], list[str]]:
    """Return (problems, summary) for one entry file.

    The summary is returned rather than printed so that a file with problems
    cannot emit an ``ok`` line on its way to failing. A gate that says "ok" and
    then exits non-zero is worse than one that says nothing.

    ``require_complete`` enforces the pinned criterion set. It is on for the
    real entry and off for the test suite's partial fixtures, which is what
    lets those fixtures stay small and structural.
    """
    problems: list[str] = []
    summary: list[str] = []

    if not path.exists():
        return [f"{path} does not exist"], summary

    try:
        raw = path.read_text(encoding="utf-8")
    except OSError as error:
        return [f"{path} cannot be read: {error}"], summary

    try:
        document = json.loads(raw)
    except json.JSONDecodeError as error:
        return [f"{path} is not valid JSON: {error}"], summary

    if not isinstance(document, dict):
        return [f"{path} must hold a JSON object, found {type(document).__name__}"], summary

    statuses: dict[str, object] = {}
    justifications: dict[str, object] = {}

    for key, value in document.items():
        if key in NON_CRITERIA_FIELDS:
            continue
        if key.endswith(STATUS_SUFFIX):
            name = key[: -len(STATUS_SUFFIX)]
            statuses[name] = value
            if not CRITERION_NAME.match(name):
                problems.append(f"{key}: {name!r} is not a criterion-name shape")
            continue
        if key.endswith(JUSTIFICATION_SUFFIX):
            name = key[: -len(JUSTIFICATION_SUFFIX)]
            justifications[name] = value
            if not CRITERION_NAME.match(name):
                problems.append(f"{key}: {name!r} is not a criterion-name shape")
            continue
        problems.append(f"{key}: neither a documented field nor a criterion field")

    for name in sorted(set(statuses) ^ set(justifications)):
        side = (
            "has a status but no justification"
            if name in statuses
            else "has a justification but no status"
        )
        problems.append(f"{name} {side}")

    for name, value in sorted(statuses.items()):
        if not isinstance(value, str):
            problems.append(f"{name}_status: {value!r} is not a string")
            continue
        if value.strip().casefold() not in {s.casefold() for s in VALID_STATUSES}:
            problems.append(
                f"{name}_status: {value!r} is not one of {', '.join(sorted(VALID_STATUSES))}"
            )

    for name, value in sorted(justifications.items()):
        if not isinstance(value, str):
            problems.append(f"{name}_justification: {value!r} is not a string")
        elif not value.strip():
            problems.append(f"{name}_justification: is empty")

    if require_complete:
        present = set(statuses)
        for name in sorted(EXPECTED_CRITERIA - present):
            series = "Baseline" if name in BASELINE_CRITERIA else "Metal"
            problems.append(
                f"{name}: absent from the {series} series. Both halves were removed, "
                "so nothing above noticed; the badge would omit this answer silently."
            )
        for name in sorted(present - EXPECTED_CRITERIA):
            problems.append(f"{name}: not in either pinned criterion set for this repository")
        # A field in the wrong series is as silently dropped as a missing one.
        for name in sorted(present & BASELINE_CRITERIA):
            if name in present and not name.startswith("osps_"):
                problems.append(f"{name}: a Baseline criterion must be named osps_*")
        for name in sorted(present & METAL_CRITERIA):
            if name.startswith("osps_"):
                problems.append(f"{name}: a Metal criterion must not be named osps_*")

    summary.append(f"{len(statuses)} criteria, {len(justifications)} justifications")
    counts: dict[str, int] = {}
    for value in statuses.values():
        if isinstance(value, str):
            counts[value] = counts.get(value, 0) + 1
    if counts:
        tally = ", ".join(f"{status} {count}" for status, count in sorted(counts.items()))
        summary.append(f"statuses: {tally}")
    ignored = sum(
        1
        for value in statuses.values()
        if isinstance(value, str) and value.strip().casefold() in {"?", "unknown"}
    )
    if ignored:
        summary.append(f"{ignored} placeholder '?' or 'unknown' - the badge ignores these")

    return problems, summary


def main() -> int:
    """Check the repository's own entry file.

    There is deliberately no path argument. An earlier version accepted one, and
    SonarCloud flagged it: a script that reads whatever path it is handed is a
    path-injection surface, which matters more than usual for a file an AI agent
    may be asked to validate. Nothing needed the argument - check-all.sh calls
    this with none, and the test suite imports check() directly with a Path.
    """
    problems, summary = check(ENTRY, require_complete=True)
    if problems:
        for problem in problems:
            print(f"  FAIL  {problem}", file=sys.stderr)
        print(f"\n{len(problems)} problem(s) in {ENTRY}", file=sys.stderr)
        return 1
    print(f"  ok    {ENTRY.name} is structurally valid")
    print(
        f"  ok    complete against all {len(EXPECTED_CRITERIA)} pinned criteria "
        f"({len(BASELINE_CRITERIA)} Baseline, {len(METAL_CRITERIA)} Metal)"
    )
    for line in summary:
        print(f"  ok    {line}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
