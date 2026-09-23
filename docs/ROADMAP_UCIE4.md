# UCIe 4.0 Readiness Roadmap

## Status

This repository does not assume that a public UCIe 4.0 specification exists. As of 23 Sep 2026, the UCIe Consortium public specification page identifies UCIe 3.0 as the current released revision.

## Why the code is "4.0-ready"

The project isolates future-evolution points without inventing 4.0 requirements:

- `rtl/ucie_adapter_pkg.sv`: widths, constants, state types
- TX/RX reliability blocks: replaceable policy logic
- link manager: extensible state machine
- channel model: independent PHY abstraction
- UVM environment: requirement-driven tests
- traceability matrix: explicit source-to-RTL-to-test mapping

## Milestones

### M1 — Reliability hardening — COMPLETE
- replay overwrite protection
- sequence-wrap collision blocking
- duplicate suppression
- sequence-gap detection
- reference-model retry budget
- directed regressions

### M2 — Timeout and retry escalation — COMPLETE
- per-entry automatic ACK timeout
- timeout-triggered replay scheduling
- per-sequence retry accounting
- bounded retry exhaustion
- fail-stop link-fault latch
- administrative reliability-state flush
- timeout/recovery directed and model tests

### M3 — Verification closure — NEXT
- exact duplicate-history tracking
- UVM functional coverage collector
- error/backpressure/state/retry crosses
- reset/disable during outstanding traffic
- timeout/retry/link-fault SVA
- deterministic seeds and regression summaries
- Verilator lint in CI

### M4 — Performance/implementation
- pipelined CRC option
- throughput and latency counters
- synthesis, area, Fmax, and power proxy reports

### M5 — Official future revision mapping
After an official UCIe 4.0 release, add paraphrased requirement IDs, tests, and traceability before changing claims or labels.
