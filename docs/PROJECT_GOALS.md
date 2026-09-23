# ChipletLink project goals

## Status and conformance boundary

ChipletLink is an educational/research RTL and verification platform. It is not UCIe-compliance-certified.

The repository uses publicly released UCIe 3.0 architectural concepts as its standards-grounded baseline. Future-revision behavior is isolated behind explicit extension points. The term **UCIe4-Ready** describes forward-looking architectural extensibility only; it does not claim implementation of, certification against, or access to an unpublished UCIe 4.0 specification.

The digital interfaces in this repository are research abstractions. The project does not redistribute the UCIe specification.

## Project goal

Build a synthesizable, configurable die-to-die adapter and a reusable SystemVerilog/UVM verification platform for studying reliable chiplet communication.

The project is intended to demonstrate the complete engineering loop: architecture, RTL, reference modeling, directed verification, constrained-random verification, assertions, functional coverage, fault injection, regression, observability, and implementation evidence.

## Engineering objectives

1. **Synthesizable adapter RTL** — accept protocol-side traffic, protect and sequence it, transport it across a logical die-to-die interface, and reconstruct it at the receiver.
2. **Explicit link management** — deterministic reset, initialization, active, recovery, disabled/fail-stop, and clean restart behavior.
3. **End-to-end data integrity** — repository-defined CRC, sequence tracking, ACK/retry, replay retention, timeout handling, and bounded retry escalation.
4. **Fault-oriented design** — make corruption, loss, duplication, ordering faults, timeout, backpressure, reset, and disable scenarios observable and testable.
5. **Reusable UVM environment** — drivers, monitors, scoreboards/reference models, coverage, assertions, virtual sequences, and controlled fault injection.
6. **Verification closure** — map requirements to tests/assertions/coverage and preserve deterministic regression evidence.
7. **Implementation evidence** — collect synthesizable counters and reproducible structural synthesis reports without making unsupported timing or compliance claims.
8. **Forward extensibility** — isolate widths, link profiles, reliability policy, capabilities, and future protocol-version behavior behind parameters or dedicated boundaries.

## Logical architecture

```text
Protocol / Host
      |
      v
+------------------+
| Protocol Adapter |
+------------------+
      |
      v
+------------------+
| TX Reliability   |
| seq / CRC / ACK  |
| replay / timeout |
+------------------+
      |
      v
+------------------+
| Link Management  |
+------------------+
      |
      v
==== logical die-to-die channel ====
      |
      v
+------------------+
| RX Reliability   |
| CRC / ordering   |
| duplicate filter |
+------------------+
      |
      v
Protocol / Host
```

The initial PHY boundary is deliberately digital. It does not claim analog front-end, package-channel, or electrical compliance implementation.

## Reliability behavior

The research baseline covers:

- CRC-protected flits
- monotonically managed sequence IDs
- exact bounded duplicate history
- ACK and requested replay
- replay-buffer retention until ACK
- automatic ACK timeout
- bounded replay retry budget
- replay-miss detection
- retry-exhaustion fail-stop
- sequence-gap detection
- backpressure-safe valid/ready behavior
- reset and administrative-disable reliability epochs
- link-health and performance counters

Every mechanism should have at least one independent verification path: directed test, constrained-random scenario, assertion, coverage point/cross, reference-model check, or a justified combination.

## Verification strategy

The verification environment combines:

- **Directed smoke tests** for deterministic protocol and corner-case behavior.
- **Constrained-random UVM** for traffic, ordering, timing, backpressure, and fault combinations.
- **Reference-model checking** for expected end-to-end delivery and reliability state.
- **SystemVerilog Assertions** for protocol invariants and temporal safety properties.
- **Functional coverage** for link states, error classes, traffic conditions, recovery outcomes, and important crosses.
- **Deterministic seeded regressions** with machine-readable summaries.
- **Open-source CI** using Python regression, Verilator lint, Icarus RTL smoke, and bounded structural synthesis evidence where the frontend supports the RTL subset.

## Core verification properties

The project should maintain evidence that:

- corrupted traffic is never silently delivered;
- accepted good traffic is delivered exactly once and in order;
- a CRC mismatch requests recovery rather than generating a successful ACK;
- a recognized duplicate can be re-ACKed without redelivery;
- a sequence gap requests the exact expected sequence;
- replay reproduces the retained payload and CRC;
- ACK frees only the matching live replay entry;
- sequence wrap cannot alias a still-outstanding sequence;
- missing ACK eventually triggers replay;
- retries terminate at the configured budget and expose a fault;
- a stalled transfer remains stable until handshake;
- reset/disable cannot leak an old outstanding transfer into a new reliability epoch.

## Forward-ready extension points

Implementation work should keep future behavior isolated around parameters or profiles such as:

```text
DATA_WIDTH / FLIT_WIDTH
SEQ_WIDTH
REPLAY_DEPTH
ACK_TIMEOUT_CYCLES
MAX_RETRIES
DUP_WINDOW
PERF_COUNTER_WIDTH
LINK_PROFILE
CAPABILITY_VECTOR
LANE_COUNT
```

A later UCIe revision should only be represented as standards behavior after that revision is publicly available and its requirements can be independently verified.

## Non-goals

The current research platform does not claim:

- UCIe Consortium certification;
- complete UCIe 3.0 compliance;
- UCIe 4.0 compliance;
- production-qualified analog PHY design;
- package/channel electrical signoff;
- official interoperability certification;
- proprietary Consortium test content;
- silicon-characterized timing or power.

## Success criteria

A milestone is complete only when the corresponding implementation and evidence agree. Long-term success means the repository can demonstrate:

1. correct normal bidirectional transfer;
2. deterministic error detection and recovery;
3. bounded behavior under lost ACK/retry scenarios;
4. no silent corruption, replay overwrite, or duplicate delivery;
5. reproducible assertion/coverage/regression evidence;
6. synthesizable, parameterized RTL for the targeted digital blocks;
7. measured reliability/performance overhead;
8. implementation reports tied to a stated tool and technology boundary;
9. clean adaptation points for later public protocol revisions.

## Long-term research directions

Potential extensions include AXI4/AXI4-Lite adaptation, multiple virtual channels, QoS/priority traffic, lane degradation/repair abstractions, richer telemetry, formal verification of critical control logic, FPGA prototyping, technology-specific synthesis/timing, and multi-chiplet topologies.
