from __future__ import annotations

import json
import os
import pathlib
import re
import subprocess
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]


def _docs_ebus_pin_root(repo: pathlib.Path) -> pathlib.Path | None:
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
        candidates.append(pathlib.Path(os.environ["DOCS_EBUS_PIN_ROOT"]))
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


def _page(relative: str) -> pathlib.Path:
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


class PortalPVModbusContractTests(unittest.TestCase):
    def test_portal_routes_keep_semantic_and_raw_boundaries_separate(self) -> None:
        portal = (ROOT / "api/portal.md").read_text(encoding="utf-8")
        required = (
            "GET /portal/api/v1/semantic/pv/current",
            "POST /portal/api/v1/explorer/modbus/raw-read",
            "M2MCurrentSnapshot",
            "modbus_v1_raw_read",
            "semantic_pv",
            "modbus_raw_diagnostic",
            "disabled independently by default",
        )
        for phrase in required:
            self.assertIn(phrase, portal)
        self.assertIn("accepts no endpoint, tool name, profile, asset, credential, or write", portal)
        self.assertIn("must keep the raw route disabled", portal)

    def test_portal_bff_keeps_m2m_credentials_out_of_browser(self) -> None:
        contract = (ROOT / "docs/platform/public-graphql-m2m-v1.md").read_text(
            encoding="utf-8"
        )
        self.assertIn("Portal BFF Consumer Target", contract)
        normalized = " ".join(contract.split())
        self.assertIn(
            "Browser code does not call this listener and never receives its "
            "server trust material, listener address, or asset identity.",
            normalized,
        )
        self.assertIn("exact canonical query over TLS 1.3", normalized)
        self.assertIn(
            "without requiring a client certificate or deriving a client principal",
            normalized,
        )
        self.assertIn("It verifies the configured server identity", normalized)
        self.assertIn("generic Portal listener does not mount the M2M", contract)
        self.assertIn("cannot add fields", contract)

    def test_raw_portal_reuses_mcp_limits_and_quota(self) -> None:
        mcp = _page("api/modbus-v1-mcp.md").read_text(encoding="utf-8")
        self.assertIn("FMV3-M5-06 Portal Reuse Target", mcp)
        self.assertIn("same closed `modbus_v1_raw_read` operation core", mcp)
        self.assertIn("four-reads-per-second runtime quota", mcp)
        self.assertIn("fifth combined MCP-or-Portal request", mcp)
        self.assertIn("before wire I/O", mcp)

    def test_public_graphql_contract_has_no_raw_modbus_expansion(self) -> None:
        sdl = (ROOT / "api/public-graphql-m2m-v1.graphql").read_text(
            encoding="utf-8"
        ).lower()
        for forbidden in ("register", "wire_bytes", "raw_read", "endpoint"):
            self.assertNotIn(forbidden, sdl)

        manifest = json.loads(
            (ROOT / "docs/platform/manifests/public-graphql-m2m-v1.json").read_text(
                encoding="utf-8"
            )
        )
        serialized = json.dumps(manifest, sort_keys=True).lower()
        for forbidden in ("raw_read", "wire_bytes", "modbus_endpoint"):
            self.assertNotIn(forbidden, serialized)


if __name__ == "__main__":
    unittest.main()
