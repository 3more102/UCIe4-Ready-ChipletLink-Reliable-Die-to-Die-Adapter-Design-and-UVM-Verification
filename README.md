# UCIe4-Ready ChipletLink — Reliable Die-to-Die Adapter Design and UVM Verification

> **Status:** educational/research RTL and verification platform. **Not UCIe-compliance-certified.**
>
> As of 23 Sep 2026, the latest publicly released UCIe specification listed by the UCIe Consortium is **UCIe 3.0**. This repository therefore uses public UCIe 3.0 architectural concepts as the standards-grounded baseline and keeps future-version behavior behind explicit extension points. No unverified UCIe 4.0 behavior is claimed.

## Project goal

Design and UVM-based verification of a reliable die-to-die adapter for chiplet systems:

- FDI-like protocol-side and RDI-like link-side educational abstractions
- link initialization, recovery, and fail-stop state handling
- 256-bit flits with repository-defined CRC-32 consistency check
- sequence numbering
- ACK / retry control
- replay buffer with collision-safe allocation
- automatic ACK timeout
- bounded replay retry budget
- backpressure-safe handshakes
- duplicate suppression and sequence-gap detection
- injected corruption and recovery testing
- SystemVerilog Assertions (SVA)
- UVM constrained-random stimulus, monitors, scoreboard and coverage hooks
- Python golden reliability model
- synthesizable performance and reliability observability counters

## Conformance boundary

The interfaces are simplified educational abstractions. This repository does **not** claim complete UCIe 3.0 compliance and does not claim UCIe 4.0 compliance before an official public 4.0 specification exists.

## Verified engineering milestones

### M1 — replay/order hardening

- CRC protection and corruption detection
- sequence IDs
- ACK/retry and replay
- selective-ACK-safe replay allocation
- live-sequence collision blocking at sequence wrap
- receiver duplicate suppression with re-ACK
- out-of-order/gap detection requesting the next expected sequence
- link recovery on CRC or sequence error

### M2 — timeout and retry escalation

- per-entry ACK aging
- automatic timeout-triggered replay
- bounded retry count
- retry-exhaustion status with failing sequence ID
- fail-stop link-fault latch on unrecoverable replay failure
- administrative disable flushes reliability state and permits a clean re-enable
- race handling for ACK arrival while replay is pending

### M3 — verification closure

- exact duplicate-history tracking
- UVM reliability functional coverage with state/error/backpressure crosses
- reset and administrative-disable regressions while reliability state is outstanding
- SVA for link gating, stalled-transfer stability, retry behavior, duplicate re-ACK, and fatal-fault latching
- deterministic Questa seed runner
- machine-readable UVM regression summary at `reports/uvm/summary.json`
- Verilator RTL lint in GitHub Actions

### M4-A — performance observability

- synthesizable saturating performance counters
- active-link cycles
- protocol-side TX accepts
- RDI TX transfers
- protocol-side RX deliveries
- retry-request count
- reliability-error event count
- TX backpressure stall cycles
- replay overhead observable as `RDI transfers - protocol accepts`
- directed regression for clean traffic, backpressure, and replay overhead

## Quick checks

```bash
python -m pytest -q
make lint
make smoke
```

Current automated evidence:
- **14 Python reliability tests**
- **7 directed RTL smoke targets**
  - corruption → retry → replay
  - selective-ACK replay integrity
  - duplicate/order handling
  - ACK timeout → bounded retry exhaustion → fail-stop
  - administrative disable → reliability epoch flush
  - reset with an outstanding flit → no stale replay, sequence epoch restarts
  - performance counters → clean accepts, backpressure stalls, retry/replay overhead
- Verilator RTL lint

For a simulator installation that provides UVM:

```bash
SEEDS="1 7 42 31415" ./scripts/run_questa_regression.sh
```

The seeded runner writes per-seed logs plus a JSON summary. It is intentionally separate from the open-source CI jobs because the repository does not redistribute a commercial simulator.

## Performance counter semantics

The M4-A counters are cumulative from hardware reset and saturate instead of wrapping. Administrative link disable does not clear them, so measurements can span multiple reliability epochs.

`perf_fdi_tx_accepts_o` counts new protocol-side traffic while `perf_rdi_tx_transfers_o` counts every physical-side transfer, including replays. Their difference therefore exposes retry/replay transmission overhead for a measurement interval that starts at reset.

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
- missing ACK automatically triggers replay
- retries stop at the configured budget and raise a link fault
- backpressure cannot change an in-flight payload
- normal data transfer is blocked while the link is inactive or faulted
- reset/disable cannot leak pre-reset outstanding traffic into a new reliability epoch
- performance counters distinguish new accepted traffic from replayed physical transfers

## Next engineering frontier

M4 continues with implementation evidence:
- optional pipelined CRC datapath
- latency instrumentation
- synthesis automation
- machine-readable area/Fmax reports
- implementation comparison of combinational and pipelined CRC

## Standards references

Normative released-revision source:
- https://www.uciexpress.org/specifications
- https://www.uciexpress.org/press-releases
- https://www.uciexpress.org/ucie-resources

UVM:
- https://www.accellera.org/downloads/standards/uvm

## License

MIT for original repository code. UCIe and related marks/specifications belong to their respective owners. This repository does not redistribute the UCIe specification.
