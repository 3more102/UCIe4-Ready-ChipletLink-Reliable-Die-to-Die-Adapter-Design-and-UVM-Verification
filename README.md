# UCIe4-Ready ChipletLink — Reliable Die-to-Die Adapter Design and UVM Verification

> **Status:** educational/research RTL and verification platform. **Not UCIe-compliance-certified.**
>
> As of 23 Sep 2026, the latest publicly released UCIe specification listed by the UCIe Consortium is **UCIe 3.0**. This repository therefore uses public UCIe 3.0 architectural concepts as the standards-grounded baseline and keeps future-version behavior behind explicit extension points. No unverified UCIe 4.0 behavior is claimed.

## Project goal

Design and UVM-based verification of a reliable die-to-die adapter for chiplet systems:

- FDI-like protocol-side and RDI-like link-side educational abstractions
- link initialization and recovery state machine
- 256-bit flits with repository-defined CRC-32 consistency check
- sequence numbering
- ACK / retry control
- replay buffer with collision-safe allocation
- backpressure-safe handshakes
- duplicate suppression and sequence-gap detection
- injected corruption and recovery testing
- SystemVerilog Assertions (SVA)
- UVM constrained-random stimulus, monitors, scoreboard and coverage
- Python golden reliability model

## Conformance boundary

The interfaces are simplified educational abstractions. This repository does **not** claim complete UCIe 3.0 compliance and does not claim UCIe 4.0 compliance before an official public 4.0 specification exists.

## Current milestone

### M1 reliability hardening

Implemented:
- CRC protection and corruption detection
- sequence IDs
- ACK/retry and replay
- selective-ACK-safe replay allocation
- live-sequence collision blocking at sequence wrap
- receiver duplicate suppression with re-ACK
- out-of-order/gap detection requesting the next expected sequence
- link recovery on CRC or sequence error
- Python reference-model retry budget and wrap tests

Next:
- automatic ACK timeout and bounded retry exhaustion in RTL
- richer UVM coverage crosses and negative tests
- performance counters and pipelined CRC

## Quick checks

```bash
python -m pytest -q
make smoke
```

The Python suite contains 12 reliability tests. `make smoke` runs link recovery, replay-buffer selective-ACK, and duplicate/order directed RTL tests with Icarus Verilog.

## Repository layout

```text
rtl/                 Synthesizable SystemVerilog RTL
verification/        UVM, interfaces, channel model, SVA, top
smoke/               Directed RTL tests
model/               Python golden reliability/CRC model
tests/               Python regression tests
docs/                Architecture, scope, verification plan, roadmap, traceability
.github/workflows/    CI
```

## Verification targets

- corrupted flits never reach the protocol-side output
- accepted good flits are delivered exactly once and in order
- CRC mismatch raises retry rather than ACK
- recent duplicate replay is re-ACKed but not re-delivered
- a sequence gap requests the exact next expected sequence
- retry of a retained sequence reproduces the original payload
- ACK frees only the matching replay entry
- selective ACK cannot cause overwrite of another live replay entry
- a wrapped sequence number cannot be reallocated while still outstanding
- backpressure cannot change an in-flight payload
- normal data transfer is blocked while the link is inactive

## Standards references

Normative released-revision source:
- https://www.uciexpress.org/specifications
- https://www.uciexpress.org/press-releases
- https://www.uciexpress.org/ucie-resources

UVM:
- https://www.accellera.org/downloads/standards/uvm

## License

MIT for original repository code. UCIe and related marks/specifications belong to their respective owners. This repository does not redistribute the UCIe specification.
