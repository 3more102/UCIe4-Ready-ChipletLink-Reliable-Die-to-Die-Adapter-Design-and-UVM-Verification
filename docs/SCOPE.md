# Scope and Conformance Boundary

## Public baseline

As of 23 Sep 2026, UCIe 3.0 is the latest publicly released revision listed by the UCIe Consortium. The repository uses only public architectural concepts as inspiration and does not redistribute specification text.

## In scope

- synthesizable educational die-to-die adapter
- FDI-like protocol-side streaming abstraction
- RDI-like link-side streaming abstraction
- link initialization/recovery FSM
- repository-defined CRC integrity check
- sequence IDs
- ACK/retry control and replay storage
- selective-ACK-safe replay allocation
- wrap collision protection
- duplicate suppression
- in-order sequence-gap detection
- backpressure
- corruption injection
- UVM scoreboard architecture
- SVA hooks/checkers
- directed RTL smoke tests
- Python reliability model

## Out of scope

- analog/electrical PHY
- package routing/electromagnetics
- lane training details
- exact UCIe sideband encoding
- PCIe or CXL protocol implementation
- complete UCIe parameter negotiation
- security protocol implementation
- compliance certification

## Future-version rule

No feature is tagged as an implemented UCIe 4.0 requirement until an official UCIe 4.0 specification is publicly released and a paraphrased requirement is entered into `docs/TRACEABILITY.md` with implementation and verification evidence.
