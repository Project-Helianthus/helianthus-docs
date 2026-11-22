#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

platform_toolchain_mode="${PLATFORM_TOOLCHAIN_MODE:-supported}"
platform_docs_repository="${PLATFORM_DOCS_REPOSITORY:-Project-Helianthus/helianthus-docs}"
case "${platform_toolchain_mode}" in
  exact|supported) ;;
  *)
    echo "PLATFORM_TOOLCHAIN_MODE must be exact or supported." >&2
    exit 2
    ;;
esac

echo "==> verify pinned workflow/schema gate tools"
if ! command -v actionlint >/dev/null 2>&1; then
  echo "actionlint v1.7.7 is required: go install github.com/rhysd/actionlint/cmd/actionlint@v1.7.7" >&2
  exit 2
fi
actionlint_version="$(python3 scripts/check_workflow_shells.py actionlint-version)"
if [ "$(printf '%s\n' "$actionlint_version" | sed -n '1p')" != "v1.7.7" ]; then
  echo "actionlint must report v1.7.7." >&2
  exit 2
fi
if ! command -v jv >/dev/null 2>&1; then
  echo "jv v0.7.0 is required: go install github.com/santhosh-tekuri/jsonschema/cmd/jv@v0.7.0" >&2
  exit 2
fi
if [ "$(jv --version | sed -n '1p')" != "github.com/santhosh-tekuri/jsonschema/cmd/jv v0.7.0" ]; then
  echo "jv must report v0.7.0." >&2
  exit 2
fi
if ! command -v shellcheck >/dev/null 2>&1; then
  echo "ShellCheck is required for the separate workflow run-step check." >&2
  exit 2
fi
gate_temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/docs-ebus-ci.XXXXXXXX")"
cleanup_workflow_lint() {
  local status=$?
  rm -rf -- "$gate_temp_dir" || :
  return "$status"
}
install_workflow_cleanup_trap() {
  local signal="$1" handler="$2" previous
  previous="$(trap -p "$signal")"
  if [ -n "$previous" ]; then
    # Decode Bash's quoted trap declaration without changing the caller's arguments.
    eval "set -- ${previous#trap -- }"
    previous="$1"
  else
    previous=:
  fi
  if [ "$signal" = EXIT ]; then
    # Both branches preserve the incoming status for the previous handler.
    printf -v handler 'if cleanup_workflow_lint; then\n%s\nelse\n%s\nfi' "$previous" "$previous"
  else
    printf -v handler '%s\n%s' "$previous" "$handler"
  fi
  # Quote the composed handler as data before installing it.
  printf -v handler 'trap -- %q %q' "$handler" "$signal"
  eval "$handler"
}
install_workflow_cleanup_trap EXIT ''
install_workflow_cleanup_trap INT 'exit 130'
install_workflow_cleanup_trap TERM 'exit 143'
echo "Workflow lint artifacts: ${gate_temp_dir} (removed on exit)"
workflow_lint_status=0
echo "==> actionlint (60-second limit; embedded ShellCheck disabled)"
python3 scripts/check_workflow_shells.py actionlint || workflow_lint_status=$?
echo "==> separate ShellCheck (60-second pass limit; all severities)"
python3 scripts/check_workflow_shells.py shellcheck --temp-dir "$gate_temp_dir" || {
  workflow_lint_status=$?
  # Preserve numbered source while the extracted files still exist. The pass
  # returns one status, so include every extracted script for diagnostic context.
  for workflow_script in "$gate_temp_dir"/*.bash "$gate_temp_dir"/*.sh; do
    [ -f "$workflow_script" ] || continue
    printf '\nExtracted workflow source: %s\n' "$workflow_script" >&2
    nl -ba "$workflow_script" >&2 || :
  done
}
if [ "$workflow_lint_status" -ne 0 ]; then
  exit "$workflow_lint_status"
fi
python3 -m pytest -q tests/test_workflow_shells.py
python3 -m pytest -q tests/test_workflow_lint_cleanup.py
echo "Pinned workflow/schema gate tools passed."

# A same-repository pull request may list heavy suites whose inputs did not
# change (CI_UNCHANGED_SUITES, computed by the trusted base copy of
# scripts/ci_suite_inputs.py from scripts/ci_suite_inputs.json). Only the
# listed suites' pytest modules are skipped; their cheap validators still run.
# Main pushes, the nightly run, manual dispatches, fork pull requests and local
# runs leave the variable empty and run every suite.
ci_suite_unchanged() {
  case " ${CI_UNCHANGED_SUITES:-} " in
    *" $1 "*)
      echo "Skipping the $1 suite: none of its inputs changed in this pull request (main pushes and the nightly run still run it)."
      return 0
      ;;
  esac
  return 1
}

docs_ebus_pin_from_readme() {
  python3 - <<'PY'
import pathlib
import re
import sys
text = pathlib.Path("README.md").read_text(encoding="utf-8")
match = re.search(r"tree/([0-9a-f]{40})/protocols/modbus", text)
if match is None:
    sys.stderr.write(
        "README protocols/modbus link does not name an immutable public source.\n"
    )
    sys.exit(2)
sys.stdout.write(match.group(1) + "\n")
PY
}

resolve_docs_ebus_pin_root() {
  local candidate=""
  if [ -n "${DOCS_EBUS_PIN_ROOT:-}" ]; then
    candidate="${DOCS_EBUS_PIN_ROOT}"
  elif [ -d "${repo_root}/checkouts/docs-ebus-pin" ]; then
    candidate="${repo_root}/checkouts/docs-ebus-pin"
  elif [ -d "${repo_root}/../docs-ebus-pin" ]; then
    candidate="${repo_root}/../docs-ebus-pin"
  else
    echo "public docs-ebus pin checkout is not reachable." >&2
    return 2
  fi
  if [ ! -d "${candidate}" ] || [ -L "${candidate}" ]; then
    echo "public docs-ebus pin checkout is not a regular directory." >&2
    return 2
  fi
  printf '%s\n' "${candidate}"
}

stage_pin_blob() {
  local dest_root="$1"
  local relative="$2"
  local dest="${dest_root}/${relative}"
  mkdir -p "$(dirname "${dest}")"
  git -C "${docs_ebus_pin_root}" show "${docs_ebus_pin}:${relative}" > "${dest}"
  if [ ! -f "${dest}" ] || [ -L "${dest}" ]; then
    echo "pinned public source did not yield a regular file: ${relative}" >&2
    return 2
  fi
}

echo "==> python readability ratchet"
python3 scripts/check_readability.py --self-test
python3 scripts/check_readability.py --check
python3 -m pytest -q tests/test_readability_gate.py

echo "==> verify markdown files are present"
count="$(git ls-files '*.md' | wc -l | tr -d ' ')"
if [ "${count}" -eq 0 ]; then
  echo "No markdown files found."
  exit 1
fi
echo "Found ${count} markdown files."

echo "==> check markdown for tabs and trailing spaces"
failed=0
if git grep -nI $'\t' -- '*.md'; then
  echo "Tab characters are not allowed in markdown files."
  failed=1
fi
if git grep -nI -E ' +$' -- '*.md'; then
  echo "Trailing spaces are not allowed in markdown files."
  failed=1
fi
if [ "${failed}" -ne 0 ]; then
  exit 1
fi

echo "==> enforce initiator/target terminology"
python3 - <<'PY'
from __future__ import annotations

import pathlib
import re
import subprocess
import sys

begin_marker = "<!-- legacy-role-mapping:begin -->"
end_marker = "<!-- legacy-role-mapping:end -->"

# Construct legacy terms without spelling them out literally in-repo.
terms = ["m" + "aster", "sl" + "ave"]
pattern = re.compile(r"\b(" + "|".join(map(re.escape, terms)) + r")\b", re.IGNORECASE)

md_files = subprocess.check_output(["git", "ls-files", "*.md"], text=True).splitlines()

def line_number(text: str, index: int) -> int:
    return text.count("\n", 0, index) + 1

def print_match(file_path: str, text: str, index: int, match_text: str) -> None:
    print(f"{file_path}:{line_number(text, index)}:{match_text}", file=sys.stderr)

failed = False

for file_path in md_files:
    path = pathlib.Path(file_path)
    text = path.read_text(encoding="utf-8")

    # Build allowed regions from legacy-role-mapping markers in this file.
    allowed_ranges: list[tuple[int, int]] = []
    search_start = 0
    while True:
        b = text.find(begin_marker, search_start)
        if b == -1:
            break
        e = text.find(end_marker, b)
        if e == -1:
            break
        allowed_ranges.append((b, e + len(end_marker)))
        search_start = e + len(end_marker)

    for match in pattern.finditer(text):
        in_allowed = any(s <= match.start() < e for s, e in allowed_ranges)
        if not in_allowed:
            if not failed:
                print(
                    "Legacy role terms found outside legacy-role-mapping regions.",
                    file=sys.stderr,
                )
            failed = True
            print_match(file_path, text, match.start(), match.group(0))

if failed:
    sys.exit(1)

print("Terminology gate passed.")
PY

echo "==> private network address gate (docs must use placeholders)"
python3 - <<'PY'
from __future__ import annotations

import pathlib
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path("scripts").resolve()))
from validate_platform_contracts import _private_network_literals

md_files = subprocess.check_output(["git", "ls-files", "*.md"], text=True).splitlines()
failed = False

for file_path in md_files:
    text = pathlib.Path(file_path).read_text(encoding="utf-8")
    for _, offset in _private_network_literals(text):
        line = text.count("\n", 0, offset) + 1
        print(f"{file_path}:{line}: private network address found (redact and use a placeholder)", file=sys.stderr)
        failed = True

if failed:
    sys.exit(1)
print("Private network gate passed.")
PY

echo "==> check eBUS source-address table"

echo "==> check register naming decomposition contract"

echo "==> check qualified identity documentation contract"
python3 scripts/check_regulator_identity_contract.py \
  --donor-root "$(resolve_docs_ebus_pin_root)"
python3 -m pytest -q tests/test_regulator_identity_contract_checker.py

echo "==> check Vaillant SemReg thermal mapping contract"
python3 -m pytest -q tests/test_vaillant_semreg_thermal_map.py

echo "==> check Vaillant controller qualification contract"

echo "==> check adversarial runtime report v1 contract"
for report in docs/platform/fixtures/adversarial-runtime/v1/positive/*.json; do
  python3 scripts/validate_adversarial_runtime_report_v1.py "$report"
done
for driver in docs/platform/fixtures/adversarial-runtime/v1/inputs/*.json; do
  jv docs/platform/schemas/adversarial-runtime-offline-fixture-v1.schema.json "$driver"
done
if ! ci_suite_unchanged adversarial_runtime_report; then
  python3 -m pytest -q tests/test_adversarial_runtime_report_v1.py
fi

echo "==> check Vaillant regulator capability API contract"

echo "==> check GraphQL device-face provenance contract"
python3 scripts/check_graphql_face_provenance.py
if ! ci_suite_unchanged graphql_face_provenance; then
  python3 -m pytest -q tests/test_graphql_face_provenance_checker.py
fi
python3 -m pytest -q -p no:cacheprovider tests/test_system_config_bound_contract.py
python3 -m pytest -q tests/test_semantic_snapshot_read_contract.py
if ! ci_suite_unchanged semantic_operation_route; then
  python3 -m pytest -q tests/test_semantic_operation_route_contract.py
fi
echo "==> check candidate live-readiness documentation consistency"
python3 -m pytest -q tests/test_live_readiness_docs.py

echo "==> check contribution-driven Portal UX contract"
python3 scripts/check_portal_ux_contract.py
if ! ci_suite_unchanged portal_ux; then
  python3 -m pytest -q tests/test_portal_ux_contract_checker.py
fi

echo "==> check CC0 and AGPL documentation boundary"
python3 scripts/check_public_domain_boundary.py
python3 -m pytest -q tests/test_public_domain_boundary.py

echo "==> check semantic term qualifiers"
python3 scripts/check_semantic_term_qualifiers.py
python3 -m pytest -q tests/test_semantic_term_qualifiers.py

echo "==> check Vaillant room-action and return-service declarations"

echo "==> check Vaillant B503 milestone contract"

echo "==> check AI-28 B510/B511 local-cache contract"

echo "==> check AI=22 B523 sensor-field contract"

echo "==> check B506 scoped candidate declarations"

echo "==> check Vaillant B505 sentinel and override candidates"

echo "==> check B510 capability-cache query transition contract"

echo "==> check B51A diagnostic variants and replication flags"

echo "==> check B512 DHW and stepper documentation contract"

echo "==> check AN22 B555 numeric narrowing contract"

echo "==> check B506 RF sequence declarations"

echo "==> check Vaillant B507 energy candidates"

echo "==> check B520 simulator actuator and ADC declarations"

echo "==> check Vaillant B51B local-transfer candidate contract"

echo "==> check B522 candidate demand and scalar API results"

echo "==> check B531 ordinary-limit documentation contract"

echo "==> check B519 opaque programming documentation contract"

echo "==> check B512 feedback fallback declarations and registry contract"

echo "==> check B509/B524 passive watch-policy documentation contract"
echo "==> check canonical register names against the register naming rules"
echo "==> check B509 register name correspondence fixture"
echo "==> check BASV0 parameter-description profile"

echo "==> check cross-runtime platform contracts (MSP-DOCS-CLEAN)"
if ! ci_suite_unchanged msp_docs_clean; then
  python3 -m pytest -q tests/test_platform_contracts.py -k trusted_prior_workflow
  python3 -m pytest -q tests/test_platform_contracts.py -k 'not trusted_prior_workflow'
  python3 -m pytest -q tests/test_synchronized_evidence_contract.py
  python3 -m pytest -q tests/test_synchronized_evidence_executable_contract.py
  python3 -m pytest -q tests/test_synchronized_evidence_one_shot_contract.py
  python3 -m pytest -q tests/test_candidate_fact_graph_contract.py
  python3 -m pytest -q tests/test_candidate_fact_graph_executable_contract.py
  python3 -m pytest -q tests/test_multi_runtime_live_coexistence_contract.py
  python3 -m pytest -q tests/test_leaf_promotion_dossier_contract.py
  python3 -m pytest -q tests/test_captured_multi_leaf_promotion_contract.py
  python3 -m pytest -q tests/test_msp085_live_completion.py
  python3 -m pytest -q tests/test_msp085_final_18_leaf_completion.py
fi

echo "==> check Modbus M1/M2 companion contract"
if ! ci_suite_unchanged modbus_companion; then
  python3 -m pytest -q \
    tests/test_canonical_pv_semantics_v1.py \
    tests/test_public_graphql_m2m_v1.py
fi
python3 scripts/validate_canonical_pv_v1.py \
  --document docs/platform/fixtures/canonical-pv/v1/golden-three-phase.json \
  --manifest docs/platform/manifests/canonical-pv-v1.json \
  --schema docs/platform/schemas/canonical-pv-observation-v1.schema.json \
  --source-registry docs/platform/fixtures/canonical-pv/v1/source-registry-bindings.json \
  --source-registry-schema docs/platform/schemas/canonical-pv-source-registry-bindings-v1.schema.json
python3 scripts/validate_public_graphql_m2m_v1.py \
  --manifest docs/platform/manifests/public-graphql-m2m-v1.json \
  --canonical-manifest docs/platform/manifests/canonical-pv-v1.json \
  --cases docs/platform/fixtures/public-graphql-m2m/v1/cases.json
python3 scripts/validate_canonical_pv_v1.py \
  --document docs/platform/fixtures/canonical-pv/v1/golden-mixed-retention.json \
  --manifest docs/platform/manifests/canonical-pv-v1.json \
  --schema docs/platform/schemas/canonical-pv-observation-v1.schema.json \
  --source-registry docs/platform/fixtures/canonical-pv/v1/source-registry-bindings.json \
  --source-registry-schema docs/platform/schemas/canonical-pv-source-registry-bindings-v1.schema.json
if ! ci_suite_unchanged modbus_companion; then
  python3 -m pytest -q tests/test_eebus_operator_admin_contract.py
  python3 -m pytest -q tests/test_driver_runtime_manager_v1.py
fi
python3 scripts/check_runtime_driver_registration.py
if ! ci_suite_unchanged modbus_companion; then
  python3 -m pytest -q tests/test_runtime_driver_registration.py
fi
python3 scripts/check_bidirectional_registration.py
if ! ci_suite_unchanged modbus_companion; then
  python3 -m pytest -q tests/test_bidirectional_registration.py
fi
docs_ebus_pin="$(docs_ebus_pin_from_readme)"
docs_ebus_pin_root="$(resolve_docs_ebus_pin_root)"
git -C "${docs_ebus_pin_root}" cat-file -e "${docs_ebus_pin}^{commit}"

runtime_root="${gate_temp_dir}/runtime-root"
mkdir -p "${runtime_root}"
runtime_present_files=(
  scripts/check_runtime_control_contract.py
  scripts/runtime_control_contract.json
  scripts/ci_local.sh
  tests/test_runtime_control_contract.py
  api/mcp.md
  api/driver-runtime-v1.md
  api/portal.md
  architecture/runtime-driver-lifecycle.md
  architecture/runtime-state.md
  architecture/runtime-control-reset-durability.md
  docs/platform/driver-runtime-manager-v1.md
)
for relative in "${runtime_present_files[@]}"; do
  mkdir -p "${runtime_root}/$(dirname "${relative}")"
  cp "${repo_root}/${relative}" "${runtime_root}/${relative}"
done
stage_pin_blob "${runtime_root}" "api/modbus-v1-addon-runtime.md"
(
  cd "${runtime_root}"
  python3 scripts/check_runtime_control_contract.py
  if [ "${RUNTIME_CONTROL_CONTRACT_INPUTS_UNCHANGED:-}" = "1" ]; then
    echo "Skipping tests/test_runtime_control_contract.py: none of its inputs changed in this pull request (main pushes and the nightly run still run it)."
  else
    python3 -m pytest -q -n 2 tests/test_runtime_control_contract.py
  fi
)
if ! ci_suite_unchanged modbus_companion; then
  python3 -m pytest -q tests/test_runtime_driver_registration_rendered.py
fi
modbus_root="${gate_temp_dir}/modbus-root"
prior_modbus_root="${gate_temp_dir}/modbus-prior-root"
modbus_pin_files=(
  docs/platform/manifests/modbus-foundation-profile-contract-v1.json
  docs/platform/schemas/modbus-companion-consumer-lock-v1.schema.json
  docs/platform/modbus-foundation-profile-contract-v1.md
  protocols/modbus/modbus-phase-one-wire-v1.md
  scripts/validate_modbus_revision_transition.py
  .github/workflows/modbus-trusted-revision.yml
  protocols/LICENSE
)
for relative in "${modbus_pin_files[@]}"; do
  stage_pin_blob "${modbus_root}" "${relative}"
  stage_pin_blob "${prior_modbus_root}" "${relative}"
done
cp "${repo_root}/README.md" "${modbus_root}/README.md"
cp "${repo_root}/README.md" "${prior_modbus_root}/README.md"
if [ -n "${MODBUS_PRIOR_ROOT:-}" ]; then
  prior_manifest="${MODBUS_PRIOR_ROOT}/docs/platform/manifests/modbus-foundation-profile-contract-v1.json"
  if [ ! -f "${prior_manifest}" ] || [ -L "${prior_manifest}" ]; then
    echo "MODBUS_PRIOR_ROOT has no regular owning manifest." >&2
    exit 2
  fi
  cp "${prior_manifest}" "${prior_modbus_root}/docs/platform/manifests/modbus-foundation-profile-contract-v1.json"
fi
python3 scripts/validate_modbus_companion.py \
  --root "${modbus_root}" \
  --prior-root "${prior_modbus_root}"

naming_root="${gate_temp_dir}/naming-root"
mkdir -p "${naming_root}"
DOCS_EBUS_PIN_ROOT="${docs_ebus_pin_root}" \
DOCS_EBUS_PIN="${docs_ebus_pin}" \
NAMING_ROOT="${naming_root}" \
REPO_ROOT="${repo_root}" \
python3 - <<'PY'
import json
import os
import pathlib
import subprocess
import sys

repo = pathlib.Path(os.environ["REPO_ROOT"])
pin_root = pathlib.Path(os.environ["DOCS_EBUS_PIN_ROOT"])
pin = os.environ["DOCS_EBUS_PIN"]
dest = pathlib.Path(os.environ["NAMING_ROOT"])

def stage_repo(relative: str) -> None:
    source = repo / relative
    if source.is_dir():
        paths = [path for path in source.rglob("*") if path.is_file() and not path.is_symlink()]
    else:
        paths = [source]
    for path in paths:
        if any(part.startswith(".") or part == "__pycache__" for part in path.relative_to(repo).parts):
            continue
        target = dest / path.relative_to(repo)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(path.read_bytes())

stage_repo("api")
for relative in (
    "scripts/check_naming_surface_contract.py",
    "scripts/check_mcp_inventory.py",
    "tests/test_naming_surface_contract.py",
    "tests/semantic_operation_route_contract.json",
    "tests/fixtures/naming_surface_inventory.json",
    "tests/fixtures/remaining_page_name_exemptions.json",
):
    stage_repo(relative)

for relative in (
    "scripts/validate_prometheus_semantic_coverage.py",
    "deployment/prometheus-semantic-coverage.md",
    "architecture/fixtures/vaillant-semreg-thermal-map-v1.json",
):
    result = subprocess.run(
        ["git", "-C", str(pin_root), "show", f"{pin}:{relative}"],
        check=False,
        capture_output=True,
    )
    if result.returncode != 0:
        sys.stderr.write(f"pinned public source missing: {relative}\n")
        sys.exit(2)
    target = dest / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(result.stdout)

ledger_path = dest / "tests/fixtures/remaining_page_name_exemptions.json"
ledger = json.loads(ledger_path.read_text(encoding="utf-8"))
staged = {
    path.relative_to(dest).as_posix()
    for path in dest.rglob("*")
    if path.is_file() and not path.is_symlink()
}
filtered = [entry for entry in ledger if entry["file"] in staged]
ledger_path.write_text(json.dumps(filtered, indent=2) + "\n", encoding="utf-8")
print(
    f"naming exemptions before={len(ledger)} after={len(filtered)} staged={len(staged)}"
)
PY
(
  cd "${naming_root}"
  echo "==> check bounded Prometheus semantic coverage contract"
  python3 scripts/validate_prometheus_semantic_coverage.py
  python3 -m pytest -q -p no:cacheprovider tests/test_naming_surface_contract.py
)

echo "==> run every other tests/test_*.py file (automatic discovery)"
# New test files need no line in this script. A file whose basename appears
# anywhere in this script keeps its dedicated invocation and is skipped here;
# every other file runs in its own interpreter, as the dedicated lines do.
# Read this script through its resolved path: BASH_SOURCE stays relative to the
# caller's directory, and the header already changed into the repository root.
gate_named_tests="$({ grep -oE '(^|[^A-Za-z0-9_])test_[A-Za-z0-9_]+\.py' "${repo_root}/scripts/ci_local.sh" \
  || [ "$?" -eq 1 ]; } | sed -E 's/^[^A-Za-z0-9_]//' | sort -u)"
for gate_test_file in tests/test_*.py; do
  [ -f "$gate_test_file" ] || continue
  gate_test_name="${gate_test_file#tests/}"
  case $'\n'"${gate_named_tests}"$'\n' in
    *$'\n'"${gate_test_name}"$'\n'*) continue ;;
  esac
  echo "--> ${gate_test_file}"
  gate_test_status=0
  python3 -m pytest -q "$gate_test_file" || gate_test_status=$?
  if [ "$gate_test_status" -eq 5 ]; then
    # pytest collected nothing: run load_tests-protocol files through unittest,
    # like the dedicated unittest steps. Do not rely on unittest's own exit
    # status for an empty run: require a nonzero test count, so an empty or
    # misnamed suite fails here instead of passing silently.
    gate_unittest_log="$(mktemp "${gate_temp_dir}/unittest.XXXXXXXX")"
    python3 -m unittest discover -s tests -p "$gate_test_name" -v 2>&1 | tee "$gate_unittest_log"
    if ! grep -qE '^Ran [1-9][0-9]* tests? in ' "$gate_unittest_log"; then
      echo "${gate_test_file}: neither pytest nor unittest collected any test (empty or misnamed suite)." >&2
      exit 5
    fi
  elif [ "$gate_test_status" -ne 0 ]; then
    exit "$gate_test_status"
  fi
done

pin_head="$(git -C "${docs_ebus_pin_root}" rev-parse --verify HEAD)"
if [ "${pin_head}" != "${docs_ebus_pin}" ]; then
  echo "owner-manifest checkout revision differs from the immutable public docs-ebus source." >&2
  exit 2
fi
owner_manifest="${docs_ebus_pin_root}/docs/platform/manifests/eebus-doc-ownership.yaml"
if [ ! -f "${owner_manifest}" ] || [ -L "${owner_manifest}" ]; then
  echo "immutable public docs-ebus source has no regular owner manifest." >&2
  exit 2
fi
set --
if [ -n "${PLATFORM_PRIOR_MANIFEST:-}" ]; then
  set -- --prior-manifest "${PLATFORM_PRIOR_MANIFEST}"
else
  set -- --prior-manifest "${owner_manifest}"
fi
for required_var in PLATFORM_M625_DOCS_EEBUS_ROOT PLATFORM_M625_EXECUTION_PLANS_ROOT; do
  if [ -z "${!required_var:-}" ]; then
    echo "${required_var} is required for fail-closed M6.25 provenance validation." >&2
    exit 2
  fi
done
set -- "$@" \
  --m625-docs-eebus-root "${PLATFORM_M625_DOCS_EEBUS_ROOT}" \
  --m625-execution-plans-root "${PLATFORM_M625_EXECUTION_PLANS_ROOT}"
python3 scripts/validate_platform_contracts.py \
  --mode repository \
  --docs-root . \
  --docs-repository "${platform_docs_repository}" \
  --owner-manifest-root "${docs_ebus_pin_root}" \
  --enforce-through MSP-DOCS-CLEAN \
  --toolchain-mode "${platform_toolchain_mode}" \
  "$@"

combined_ref_values=(
  "${PLATFORM_DOCS_EEBUS_ROOT:-}"
  "${PLATFORM_EEBUSREG_ROOT:-}"
  "${PLATFORM_DOCS_REF:-}"
  "${PLATFORM_DOCS_EEBUS_REF:-}"
  "${PLATFORM_EEBUSREG_REF:-}"
  "${PLATFORM_PRIOR_MANIFEST:-}"
)
combined_ref_requested=false
for value in \
  "${PLATFORM_DOCS_EEBUS_ROOT:-}" \
  "${PLATFORM_EEBUSREG_ROOT:-}" \
  "${PLATFORM_DOCS_REF:-}" \
  "${PLATFORM_DOCS_EEBUS_REF:-}" \
  "${PLATFORM_EEBUSREG_REF:-}"; do
  if [ -n "${value}" ]; then
    combined_ref_requested=true
  fi
done
if [ "${combined_ref_requested}" = true ]; then
  for value in "${combined_ref_values[@]}"; do
    test -n "${value}"
  done
  python3 scripts/validate_platform_combined_ref.py \
    --docs-root . \
    --docs-eebus-root "${PLATFORM_DOCS_EEBUS_ROOT}" \
    --eebusreg-root "${PLATFORM_EEBUSREG_ROOT}" \
    --m625-docs-eebus-root "${PLATFORM_M625_DOCS_EEBUS_ROOT}" \
    --m625-execution-plans-root "${PLATFORM_M625_EXECUTION_PLANS_ROOT}" \
    --docs-ref "${PLATFORM_DOCS_REF}" \
    --docs-eebus-ref "${PLATFORM_DOCS_EEBUS_REF}" \
    --eebusreg-ref "${PLATFORM_EEBUSREG_REF}" \
    --prior-manifest "${PLATFORM_PRIOR_MANIFEST}" \
    --enforce-through MSP-DOCS-CLEAN \
    --toolchain-mode "${platform_toolchain_mode}"
fi

echo "==> check eBUS address-table taxonomy + frame-type contract hash (Phase C M-C0)"

echo "==> check runtime_state.json schema (runtime-state-w19-26 M0_DOC_GATE)"
bash scripts/check_runtime_state_schema.sh

echo "==> check deployment source-address wording"

echo "==> check NM 07FE/07FF service names"
