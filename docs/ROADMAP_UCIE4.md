# UCIe 4.0 Readiness Roadmap

## Status

This repository does not assume that a public UCIe 4.0 specification exists. As of 23 Sep 2026, the UCIe Consortium public specification page identifies UCIe 3.0 as the current released revision.

## Why the code is "4.0-ready"

The project isolates likely future-evolution points without inventing 4.0 requirements:

- `rtl/ucie_adapter_pkg.sv`: widths, constants, state types
- TX/RX reliability blocks: replaceable policy logic
- link manager: extensible state machine
- channel model: independent PHY abstraction
- UVM environment: requirement-driven tests
- traceability matrix: explicit source-to-RTL-to-test mapping

## Milestones

### M1 — Reliability hardening
- replay overwrite protection
- sequence-wrap collision blocking
- duplicate suppression
- sequence-gap detection
- model retry budget
- directed regressions

### M2 — Timeout and retry escalation
- automatic ACK timeout
- per-sequence or window retry accounting
- retry-exhausted status/error path
- timeout/recovery directed and UVM tests

### M3 — UVM closure
- coverage collector
- error/backpressure/state crosses
- reset during outstanding traffic
- replay occupancy and wrap scenarios
- deterministic seeds and regression summaries

### M4 — Performance/implementation
- pipelined CRC option
- throughput and latency counters
- synthesis, area, Fmax, and power proxy reports

### M5 — Official future revision mapping
After an official UCIe 4.0 release, add paraphrased requirement IDs, tests, and traceability before changing claims or labels.
