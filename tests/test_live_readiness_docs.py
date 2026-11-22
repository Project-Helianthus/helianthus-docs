"""Enforce candidate readiness documentation consistency, not runtime conformance."""
import os
from pathlib import Path
import re
import subprocess

import pytest

ROOT = Path(__file__).resolve().parents[1]


def _docs_ebus_pin_root(repo: Path) -> Path | None:
    """Return the immutable public docs-ebus checkout, when it is present."""
    readme = repo / "README.md"
    pin = None
    if readme.is_file() and not readme.is_symlink():
        match = re.search(
            r"tree/([0-9a-f]{40})/protocols/modbus",
            readme.read_text(encoding="utf-8"),
        )
        if match is not None:
            pin = match.group(1)
    candidates = []
    if os.environ.get("DOCS_EBUS_PIN_ROOT"):
        candidates.append(Path(os.environ["DOCS_EBUS_PIN_ROOT"]))
    candidates.append(repo / "checkouts" / "docs-ebus-pin")
    candidates.append(repo.parent / "docs-ebus-pin")
    for candidate in candidates:
        if not candidate.is_dir() or candidate.is_symlink():
            continue
        if pin is None:
            return candidate
        result = subprocess.run(
            ["git", "-C", str(candidate), "rev-parse", "--verify", "HEAD"],
            check=False,
            capture_output=True,
            text=True,
        )
        if result.returncode == 0 and result.stdout.strip() == pin:
            return candidate
    return None


def _page(relative: str) -> Path:
    """Prefer a page in this tree. Pages that stay with another owner are read from the public pin."""
    local = ROOT / relative
    if local.is_file() and not local.is_symlink():
        return local
    pin = _docs_ebus_pin_root(ROOT)
    if pin is not None:
        pinned = pin / relative
        if pinned.is_file() and not pinned.is_symlink():
            return pinned
    return local


DOC = _page("architecture/startup-semantic-fsm.md")
API_DOC = _page("api/graphql.md")
PAIRS = {
    "Zones": ("zonePublished", "zoneLiveSeen"),
    "DHW": ("dhwPublished", "dhwLiveSeen"),
    "Boiler status": ("boilerPublished", "boilerLiveSeen"),
    "Circuits": ("circuitPublished", "circuitLiveSeen"),
    "Radio devices": ("radioPublished", "radioLiveSeen"),
}

PROSE = (
    "**Hypothesis — candidate readiness contract.** Provenance is not published.",
    "returns `LIVE_WARMUP` on the first one",
    "On subsequent live updates it evaluates the predicate and transitions to `LIVE_READY` if it succeeds",
    "The epoch threshold belongs to the caller, not the predicate",
    "a published domain without a live observation makes the predicate false",
    "at least one of the five live observation flags, regardless of publication",
    "System and energy are not part of this predicate; energy-only updates do not satisfy it",
    "`live_epoch >= 2`: candidate for live-ready; stream criteria still apply",
    "actual device readiness remains **Unknown** without qualification",
    "it does not establish implementation conformance",
)
API_PROSE = (
    "**Hypothesis — candidate readiness contract.** Provenance is not published.",
    "`LIVE_READY` requires `live_epoch >= 2`, a live observation for every published domain (zones, DHW, boiler status, circuits, and radio devices)",
    "at least one live observation across those five domains, regardless of publication",
    "System and energy are outside the predicate; energy-only updates do not satisfy it",
    "The first live update returns `LIVE_WARMUP`; subsequent live updates evaluate the predicate",
    "Actual device readiness remains **Unknown** without qualification",
)


def check_prose(doc, phrases):
    flat = " ".join(doc.split())
    for phrase in phrases:
        assert phrase in flat, phrase


def contract(doc, api_doc):
    for domain, (published, live) in PAIRS.items():
        assert f"| {domain} | `{published}` | `{live}` |" in doc
    check_prose(doc, PROSE)
    startup = api_doc.split("## Semantic Startup Runtime Contract\n", 1)[1]
    startup = startup.split("\n## ", 1)[0]
    check_prose(startup, API_PROSE)


def test_live_readiness_document_consistency():
    contract(DOC.read_text(), API_DOC.read_text())


@pytest.mark.parametrize("phrase", PROSE)
def test_live_readiness_architecture_mutations(phrase):
    doc, api_doc = DOC.read_text(), API_DOC.read_text()
    contract(doc, api_doc)
    with pytest.raises(AssertionError):
        contract(doc.replace(phrase, "x"), api_doc)


@pytest.mark.parametrize("phrase", API_PROSE)
def test_live_readiness_api_mutations(phrase):
    doc, api_doc = DOC.read_text(), API_DOC.read_text()
    contract(doc, api_doc)
    # Match normalized whitespace so wrapped Markdown is mutated too.
    with pytest.raises(AssertionError):
        contract(doc, re.sub(r"\s+".join(re.escape(word) for word in phrase.split()), "x", api_doc))


@pytest.mark.parametrize("domain", PAIRS)
def test_live_readiness_domain_mutations(domain):
    doc, api_doc = DOC.read_text(), API_DOC.read_text()
    published, live = PAIRS[domain]
    row = f"| {domain} | `{published}` | `{live}` |"
    contract(doc, api_doc)
    with pytest.raises(AssertionError):
        contract(doc.replace(row, ""), api_doc)
