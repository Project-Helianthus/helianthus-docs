"""Public Modbus companion root and owning-revision regression.

Each case names the manifest field it changes and the production check that
rejects that change. Digests are read from the public manifest and mutated
in memory; this module does not embed them.
"""
from __future__ import annotations

import importlib.util
import json
import os
import pathlib
import re
import subprocess

import pytest


REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]
README = REPO_ROOT / "README.md"
GATE = REPO_ROOT / "scripts/ci_local.sh"
MANIFEST = "docs/platform/manifests/modbus-foundation-profile-contract-v1.json"
PIN_FILES = (
    MANIFEST,
    "docs/platform/schemas/modbus-companion-consumer-lock-v1.schema.json",
    "docs/platform/modbus-foundation-profile-contract-v1.md",
    "protocols/modbus/modbus-phase-one-wire-v1.md",
    "scripts/validate_modbus_revision_transition.py",
    ".github/workflows/modbus-trusted-revision.yml",
    "protocols/LICENSE",
)


def load_validator():
    path = REPO_ROOT / "scripts/validate_modbus_companion.py"
    spec = importlib.util.spec_from_file_location("validate_modbus_companion", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def public_pin() -> str:
    match = re.search(
        r"tree/([0-9a-f]{40})/protocols/modbus",
        README.read_text(encoding="utf-8"),
    )
    if match is None:
        pytest.fail("README protocols/modbus link does not name an immutable public source")
    return match.group(1)


def pin_root() -> pathlib.Path:
    candidates = []
    configured = os.environ.get("DOCS_EBUS_PIN_ROOT")
    if configured:
        candidates.append(pathlib.Path(configured))
    candidates.extend(
        (
            REPO_ROOT / "checkouts" / "docs-ebus-pin",
            REPO_ROOT.parent / "docs-ebus-pin",
            REPO_ROOT.parent / "checkouts" / "docs-ebus-pin",
        )
    )
    for candidate in candidates:
        if candidate.is_dir() and not candidate.is_symlink():
            return candidate
    pytest.fail("public docs-ebus pin checkout is not reachable")


def pin_bytes(relative: str) -> bytes:
    root = pin_root()
    result = subprocess.run(
        ["git", "-C", str(root), "show", f"{public_pin()}:{relative}"],
        check=False,
        capture_output=True,
    )
    if result.returncode != 0:
        pytest.fail(f"pinned public source missing: {relative}")
    return result.stdout


def stage_public_root(tmp_path: pathlib.Path, readme: str) -> pathlib.Path:
    for relative in PIN_FILES:
        target = tmp_path / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(pin_bytes(relative))
    (tmp_path / "README.md").write_text(readme, encoding="utf-8")
    return tmp_path


def flip_token(value: str) -> str:
    chars = list(value)
    chars[0] = "0" if chars[0] != "0" else "1"
    return "".join(chars)


def write_manifest(root: pathlib.Path, manifest: dict) -> None:
    path = root / MANIFEST
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(manifest), encoding="utf-8")


def test_gate_passes_a_prior_root_that_contains_the_owning_manifest() -> None:
    gate = GATE.read_text(encoding="utf-8")
    assert (
        'python3 scripts/validate_modbus_companion.py \\\n'
        '  --root "${modbus_root}" \\\n'
        '  --prior-root "${prior_modbus_root}"\n'
    ) in gate
    assert "validate_modbus_companion.py --root ." not in gate
    assert "MODBUS_PRIOR_ROOT has no regular owning manifest." in gate


def test_public_readme_boundary_uses_both_protocol_trees(tmp_path: pathlib.Path) -> None:
    validator = load_validator()
    readme = README.read_text(encoding="utf-8")
    root = stage_public_root(tmp_path / "current", readme)
    errors, _digest = validator.validate(root, root)
    assert errors == []
    broken = readme.replace(
        "https://github.com/Project-Helianthus/helianthus-docs-ebus/tree/main/protocols",
        "https://github.com/Project-Helianthus/helianthus-docs-ebus/tree/main/other",
        1,
    )
    broken_root = stage_public_root(tmp_path / "broken", broken)
    broken_errors, _digest = validator.validate(broken_root, broken_root)
    assert "README license-path boundary is incomplete" in broken_errors


def test_content_revision_must_advance_when_artifact_sha256_changes(tmp_path: pathlib.Path) -> None:
    # Catches a byte change recorded in artifact_sha256 while content_revision stays put.
    validator = load_validator()
    current = json.loads(pin_bytes(MANIFEST))
    prior = json.loads(json.dumps(current))
    prior["artifact_sha256"]["wire"] = flip_token(prior["artifact_sha256"]["wire"])
    current_root = tmp_path / "current"
    prior_root = tmp_path / "prior"
    write_manifest(current_root, current)
    write_manifest(prior_root, prior)
    errors: list[str] = []
    validator._validate_prior_revision(current, prior_root, errors)
    assert any("next content_revision" in error for error in errors)


def test_content_revision_must_advance_when_artifact_paths_change(tmp_path: pathlib.Path) -> None:
    # Catches an artifacts path change that leaves artifact_sha256 and content_revision unchanged.
    validator = load_validator()
    current = json.loads(pin_bytes(MANIFEST))
    prior = json.loads(json.dumps(current))
    prior["artifacts"]["wire"] = flip_token(prior["artifacts"]["wire"])
    current_root = tmp_path / "current"
    prior_root = tmp_path / "prior"
    write_manifest(current_root, current)
    write_manifest(prior_root, prior)
    errors: list[str] = []
    validator._validate_prior_revision(current, prior_root, errors)
    assert any("next content_revision" in error for error in errors)


def test_version_cannot_skip(tmp_path: pathlib.Path) -> None:
    # Catches a version that jumps over the next integer.
    validator = load_validator()
    prior = json.loads(pin_bytes(MANIFEST))
    current = json.loads(json.dumps(prior))
    current["version"] = prior["version"] + 2
    prior_root = tmp_path / "prior"
    write_manifest(prior_root, prior)
    errors: list[str] = []
    validator._validate_prior_revision(current, prior_root, errors)
    assert any("cannot decrease or skip" in error for error in errors)


def test_new_version_restarts_content_revision(tmp_path: pathlib.Path) -> None:
    # Catches a new version that keeps the previous content_revision.
    validator = load_validator()
    prior = json.loads(pin_bytes(MANIFEST))
    current = json.loads(json.dumps(prior))
    current["version"] = prior["version"] + 1
    current["content_revision"] = prior["content_revision"] + 1
    prior_root = tmp_path / "prior"
    write_manifest(prior_root, prior)
    errors: list[str] = []
    validator._validate_prior_revision(current, prior_root, errors)
    assert any("must start at content_revision 1" in error for error in errors)


def test_missing_prior_manifest_is_not_the_gate_path(tmp_path: pathlib.Path) -> None:
    # A missing prior file is treated as a new revision 1. The gate must not use it.
    validator = load_validator()
    current = json.loads(pin_bytes(MANIFEST))
    errors: list[str] = []
    validator._validate_prior_revision(current, tmp_path, errors)
    assert errors == []
    gate = GATE.read_text(encoding="utf-8")
    assert 'cp "${prior_manifest}"' in gate
    assert "--prior-root \"${prior_modbus_root}\"" in gate
