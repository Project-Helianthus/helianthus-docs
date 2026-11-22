# Helianthus eBUS Documentation

This repository documents the current, implemented behavior of the Helianthus eBUS ecosystem:

- `helianthus-ebusgo` (transport + protocol + data types)
- `helianthus-ebusreg` (registry + schema + vendor providers)
- `helianthus-gateway` (runtime + GraphQL/MCP + projection browser/Portal surfaces)

Implementation-neutral references for the eBUS wire protocol and data types live under `protocols/` and `types/`. Helianthus-specific architecture, APIs, and deployment notes live elsewhere in the tree.

Gateway HTTP entrypoints are split by role: `/ui` is the read-only projection browser, while `/portal` is the Portal shell and `/portal/api/v1` is its versioned API surface.

## Start Here by Role

- **Developer path:** [architecture/overview.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/architecture/overview.md) → [api/graphql.md](api/graphql.md) → [api/mcp.md](api/mcp.md) → [api/portal.md](api/portal.md) → [development/contributing.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/development/contributing.md)
- **Operator path:** [deployment/full-stack.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/deployment/full-stack.md) → [development/end-to-end-smoke.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/development/end-to-end-smoke.md) → [development/smoke-test.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/development/smoke-test.md)
- **Researcher path:** [protocols/ebus-services/ebus-overview.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/protocols/ebus-services/ebus-overview.md) → [types/overview.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/types/overview.md) → [architecture/vaillant.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/architecture/vaillant.md)

## Documentation Map

| Area | Start docs |
|---|---|
| Tree indexes | [api/index.md](api/index.md), [architecture/index.md](architecture/index.md), [deployment/index.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/deployment/index.md), [development/index.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/development/index.md), [protocols/index.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/protocols/index.md) |
| Architecture | [architecture/overview.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/architecture/overview.md), [architecture/decisions.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/architecture/decisions.md), [architecture/mcp-first-development.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/architecture/mcp-first-development.md), [architecture/nm-model.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/architecture/nm-model.md), [architecture/nm-discovery.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/architecture/nm-discovery.md), [architecture/nm-participant-policy.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/architecture/nm-participant-policy.md) |
| Platform contracts | [docs/platform/README.md](docs/platform/README.md), [docs/platform/ownership-and-doc-gates.md](docs/platform/ownership-and-doc-gates.md), [docs/platform/modbus-multivendor-boundaries.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/977614c944cd685bef75b5b12148e1110ed7653a/docs/platform/modbus-multivendor-boundaries.md), [docs/platform/modbus-foundation-profile-contract-v1.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/docs/platform/modbus-foundation-profile-contract-v1.md), [docs/platform/opaque-runtime-acquisition-v1.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/977614c944cd685bef75b5b12148e1110ed7653a/docs/platform/opaque-runtime-acquisition-v1.md), [docs/platform/manifests/opaque-runtime-acquisition-v1.json](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/977614c944cd685bef75b5b12148e1110ed7653a/docs/platform/manifests/opaque-runtime-acquisition-v1.json), [docs/platform/eebus-raw-first-contract.md](https://github.com/Project-Helianthus/helianthus-docs-eebus/blob/main/docs/platform/eebus-raw-first-contract.md), [docs/platform/eebus-ha-network-proof.md](https://github.com/Project-Helianthus/helianthus-docs-eebus/blob/main/docs/platform/eebus-ha-network-proof.md) |
| Protocols | [protocols/modbus/README.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/977614c944cd685bef75b5b12148e1110ed7653a/protocols/modbus/README.md), [protocols/ebus-services/ebus-overview.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/protocols/ebus-services/ebus-overview.md), [protocols/ebusd-tcp.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/protocols/ebusd-tcp.md), [protocols/vaillant/ebus-vaillant.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/protocols/vaillant/ebus-vaillant.md), [Vaillant regulators](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/protocols/vaillant/ebus-vaillant-regulators.md), [protocols/vaillant/ebus-vaillant-b513.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/protocols/vaillant/ebus-vaillant-b513.md), [protocols/vaillant/ebus-vaillant-b514.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/protocols/vaillant/ebus-vaillant-b514.md), [protocols/vaillant/ebus-vaillant-b515.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/protocols/vaillant/ebus-vaillant-b515.md), [protocols/vaillant/ebus-vaillant-b521.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/protocols/vaillant/ebus-vaillant-b521.md), [protocols/vaillant/ebus-vaillant-b522.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/protocols/vaillant/ebus-vaillant-b522.md), [protocols/vaillant/ebus-vaillant-b523.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/protocols/vaillant/ebus-vaillant-b523.md), [protocols/vaillant/ebus-vaillant-b524.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/protocols/vaillant/ebus-vaillant-b524.md), [B524 profile discovery](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/protocols/vaillant/ebus-vaillant-b524-profile-discovery-and-descriptions.md), [B524 bounded survey method](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/protocols/vaillant/ebus-vaillant-b524-survey-methodology.md), [B524 BASV0 description profile](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/protocols/vaillant/ebus-vaillant-b524-basv0-profile-v1.md), [protocols/vaillant/ebus-vaillant-b524-register-map.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/protocols/vaillant/ebus-vaillant-b524-register-map.md), [protocols/vaillant/ebus-vaillant-b555-timer-protocol.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/protocols/vaillant/ebus-vaillant-b555-timer-protocol.md), [protocols/brink/brink-40xx.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/protocols/brink/brink-40xx.md), [protocols/wolf/wolf-protocols.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/protocols/wolf/wolf-protocols.md), [protocols/weishaupt/weishaupt-wrsol.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/protocols/weishaupt/weishaupt-wrsol.md), [protocols/weishaupt/kromschroeder-5000.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/protocols/weishaupt/kromschroeder-5000.md) |
| Types | [types/overview.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/types/overview.md), [types/primitives.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/types/primitives.md), [types/composite.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/types/composite.md), [types/ebusd-csv.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/types/ebusd-csv.md), [types/ak25-type-representation-axes.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/types/ak25-type-representation-axes.md) |
| API | [api/graphql.md](api/graphql.md), [api/mcp.md](api/mcp.md), [api/portal.md](api/portal.md) |
| Deployment | [deployment/full-stack.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/deployment/full-stack.md), [deployment/tinygo-esp32.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/deployment/tinygo-esp32.md) |
| Development | [development/contributing.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/development/contributing.md), [development/conventions.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/development/conventions.md), [development/ha-integration.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/development/ha-integration.md) |
| Firmware | [firmware/pic16f15356-overview.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/firmware/pic16f15356-overview.md), [firmware/pic16f15356-pinout.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/firmware/pic16f15356-pinout.md), [firmware/pic16f15356-fsm.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/firmware/pic16f15356-fsm.md), [firmware/pic16f15356-timing.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/firmware/pic16f15356-timing.md), [firmware/pic16f15356-registers.md](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/firmware/pic16f15356-registers.md) |

Page file names, and so the published URLs, are lowercase kebab-case. The tree
indexes list every page of their tree, and the
[page status table](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/architecture/page-status.json) keeps the status that each
renamed page states for itself. Repository control files and the names not yet
converted are described under
[documentation page file names](architecture/naming.md#documentation-page-file-names).

## Application contracts (AGPL-3.0)

- Proposed offline local responder: [registration contract](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/api/ebus-local-responder.md) and [worker transport contract](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/architecture/local-worker-transport.md) (contract only; implementation and hardware acceptance remain open)
- [VRC Explorer B524 operation reads](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/development/ebus-vaillant-b524-operation-reads.md)
- [VRC Explorer discovery and descriptions](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/development/ebus-vaillant-b524-explorer-discovery.md)
- [BASV0 B524 description-profile reuse](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/development/ebus-vaillant-b524-basv0-profile-reuse.md)
- [VRC Explorer Browser scalar writes](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/development/ebus-vaillant-b524-browser-writes.md)
- [B524 survey contribution checks](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/development/ebus-vaillant-b524-survey-contributions.md)
- [B503 gateway contract](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/architecture/protocol-routing-vaillant-b503.md)
- [Modbus application contracts](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/977614c944cd685bef75b5b12148e1110ed7653a/architecture/protocol-routing-vendor-modbus-overview.md)
- [SunSpec application contracts](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/977614c944cd685bef75b5b12148e1110ed7653a/architecture/protocol-routing-vendor-sunspec-overview.md)

## Contribution Workflow (Doc-Gate)

- **Tier 1 (merge-blocking):** changes to architecture, API surface, or runtime behavior must update docs in the same PR; see [Trigger Matrix](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/development/contributing.md#trigger-matrix).
- **Tier 2 (non-blocking):** internal-only refactors with no external behavior change may skip doc edits, but must include a short rationale in the PR description; see [Trigger Matrix](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/development/contributing.md#trigger-matrix).
- **Author flow:** classify the change, update required docs, and complete the [PR Author Checklist](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/development/contributing.md#pr-author-checklist).
- **Reviewer flow:** verify classification and documentation coverage using the [Mandatory Gate Flow](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/development/contributing.md#mandatory-gate-flow).
- **Canonical policy:** [development/contributing.md#documentation-gate-doc-gate](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/development/contributing.md#documentation-gate-doc-gate)

## Local CI (no GitHub Actions required)

Run:

```bash
./scripts/ci_local.sh
```

The local gate runs actionlint v1.7.7 with `-shellcheck=`, then checks workflow
`run:` scripts separately with ShellCheck. Each lint pass has a 60-second limit;
findings or timeouts fail the gate. See [local gate details](https://github.com/Project-Helianthus/helianthus-docs-ebus/blob/main/development/contributing.md#local-gate).

## Licensing

This repository contains documentation under two licenses:

- [`protocols/`](https://github.com/Project-Helianthus/helianthus-docs-ebus/tree/main/protocols) and the Modbus protocols tree [`protocols/modbus`](https://github.com/Project-Helianthus/helianthus-docs-ebus/tree/977614c944cd685bef75b5b12148e1110ed7653a/protocols/modbus), and [`types/`](https://github.com/Project-Helianthus/helianthus-docs-ebus/tree/main/types) – **CC0-1.0** (public domain).
  These describe implementation-neutral wire protocols and data formats,
  including eBUS and Modbus. The path is the license boundary; a neutral wire
  reference outside these directories fails documentation review. Anyone can
  use, modify, or republish this material without restriction. Application CLI
  arguments, planner/UI behavior, APIs and application artifact schemas belong
  outside these CC0 directories, even when they operate on the same protocol.

- Everything else – **AGPL-3.0**.
  This documents the Helianthus implementation specifically.
  See the root [LICENSE](LICENSE) file for terms.
