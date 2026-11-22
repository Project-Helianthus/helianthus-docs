#!/usr/bin/env python3
"""Check the built Pages site before it is uploaded."""

from __future__ import annotations

import sys
from pathlib import Path

HOMEPAGE = "index.html"
SNAPSHOT = "api/semantic-snapshot-read/index.html"
PAGES_ORIGIN = "https://project-helianthus.github.io/helianthus-docs/"
SOURCE_LINK = (
    "https://github.com/Project-Helianthus/helianthus-docs/blob/main/"
    "api/semantic-snapshot-read.md"
)
CODE_LINK = (
    "https://github.com/Project-Helianthus/helianthus-gateway/blob/main/"
    "mcp/modbus_v1.go"
)
FORBIDDEN_PARTS = {
    "author-evidence",
    "checkouts",
    "fixtures",
    "scripts",
    "tests",
    "__pycache__",
    ".pytest_cache",
    ".ruff_cache",
    ".github",
}
FORBIDDEN_NAMES = {
    "mkdocs.yml",
    "requirements-ci.txt",
    "requirements-pages.txt",
}
FORBIDDEN_SUFFIXES = {".py", ".pyc", ".md", ".go"}


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: check_pages_site.py SITE", file=sys.stderr)
        return 2
    site = Path(argv[1])
    errors: list[str] = []
    index = site / HOMEPAGE
    snapshot = site / SNAPSHOT
    if not index.is_file():
        errors.append("missing homepage index.html")
    else:
        text = index.read_text(encoding="utf-8")
        if "Helianthus eBUS Documentation" not in text:
            errors.append("homepage is not the rendered README")
        if PAGES_ORIGIN not in text:
            errors.append("homepage canonical URL is not the project Pages path")
    if not snapshot.is_file():
        errors.append("missing semantic snapshot page")
    else:
        text = snapshot.read_text(encoding="utf-8")
        if "Shared SemReg snapshot read" not in text:
            errors.append("semantic snapshot page is not the rendered source")
        if CODE_LINK not in text:
            errors.append("code link was not kept as an absolute GitHub URL")
        if SOURCE_LINK not in text:
            errors.append("source link does not keep the repository Markdown path")
    if not (site / "css" / "base.css").is_file():
        errors.append("rendered theme assets are missing")
    for path in site.rglob("*"):
        if not path.is_file():
            continue
        relative = path.relative_to(site)
        if set(relative.parts) & FORBIDDEN_PARTS or relative.name in FORBIDDEN_NAMES:
            errors.append(f"forbidden path in artifact: {relative.as_posix()}")
        elif relative.suffix in FORBIDDEN_SUFFIXES:
            errors.append(f"unrendered source in artifact: {relative.as_posix()}")
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    print("pages publication check passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
