# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
"""The HTML release notes may use: `scripts/release-notes/<version>.html`."""

TEXT_TAGS = frozenset({"b", "li", "p"})
LIST_TAGS = frozenset({"ul"})
ALLOWED_TAGS = TEXT_TAGS | LIST_TAGS
