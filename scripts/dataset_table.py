#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel

import pathlib
import re
import sys

DATASET = pathlib.Path(__file__).resolve().parent.parent / "NepalKitCore" / "Sources" / "NepalKitCore" / "CalendarDataset.swift"


def shipped_table(dataset_path=DATASET):
    text = pathlib.Path(dataset_path).read_text(encoding="utf-8")
    try:
        block = text[text.index("\n        years: [\n"):]
        block = block[:block.index("\n        ],")]
    except ValueError:
        sys.exit("no years block found in %s — the format changed?" % dataset_path)
    rows = {int(m.group(1)): [int(x) for x in m.group(2).split(",") if x.strip()]
            for m in re.finditer(r"(\d{4}):\s*\[([\d,\s]+)\]", block)}
    if not rows:
        sys.exit("no rows parsed from %s — the format changed?" % dataset_path)
    return rows
