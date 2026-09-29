#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
"""Parse the shipped month-length table out of CalendarDataset.swift.

One parser for both provenance scripts: verify-data-sources.py compares this
table against pinned community sources, and check-kathmandu-calendar.py
spot-checks it against the live KMC calendar. Two copies drifted in technique
(see the git history of load_shipped vs shipped_table); a reformat of the
dataset literal that broke only one would produce contradictory provenance
evidence, so there is exactly one.
"""

import pathlib
import re
import sys

DATASET = pathlib.Path(__file__).resolve().parent.parent / "NepalKitCore" / "Sources" / "NepalKitCore" / "CalendarDataset.swift"


def shipped_table(dataset_path=DATASET):
    """Year -> twelve month lengths, parsed from the dataset literal.

    sys.exits rather than returning {}: a comparison that silently compared
    nothing reports success having checked nothing.
    """
    text = pathlib.Path(dataset_path).read_text(encoding="utf-8")
    # Anchor on the indented literal: the bare form also matches the `public let
    # years` declaration further up the file, and the slice would then depend on
    # nothing before the data block containing an indented `],` by luck.
    try:
        block = text[text.index("\n        years: ["):]
        block = block[:block.index("\n        ],")]
    except ValueError:
        sys.exit("no years block found in %s — the format changed?" % dataset_path)
    rows = {int(m.group(1)): [int(x) for x in m.group(2).split(",") if x.strip()]
            for m in re.finditer(r"(\d{4}):\s*\[([\d,\s]+)\]", block)}
    if not rows:
        sys.exit("no rows parsed from %s — the format changed?" % dataset_path)
    return rows
