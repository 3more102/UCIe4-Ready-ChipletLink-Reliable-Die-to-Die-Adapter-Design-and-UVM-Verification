# Requirements Traceability

| Requirement ID | Source | Paraphrased requirement | RTL / model | Test | Status |
|---|---|---|---|---|---|
| EDU-REL-001 | Project-defined | corrupted data must not be delivered | `ucie_adapter_rx.sv` | V003/V004 | Implemented |
| EDU-REL-002 | Project-defined | retained flit can be replayed by sequence | TX + replay buffer | V003 | Implemented |
| EDU-REL-003 | Project-defined | selective ACK cannot cause overwrite of another live replay entry | `ucie_replay_buffer.sv` | V011 | Implemented M1 |
| EDU-REL-004 | Project-defined | a sequence ID still outstanding at wrap cannot be reallocated | TX + replay buffer/model | V010 | Implemented M1 |
| EDU-REL-005 | Project-defined | ACK-loss replay is acknowledged but not delivered twice | `ucie_adapter_rx.sv` | V012 | Implemented M1 |
| EDU-REL-006 | Project-defined | future/gap sequence requests the next expected sequence | `ucie_adapter_rx.sv` | V013 | Implemented M1 |
| EDU-REL-007 | Project-defined | missing ACK automatically schedules retained-sequence replay | replay buffer + TX/model | V014 | Implemented M2 |
| EDU-REL-008 | Project-defined | replay attempts are bounded by a configurable retry budget | replay buffer + TX/model | V006/V015 | Implemented M2 |
| EDU-REL-009 | Project-defined | a matching ACK cancels a pending replay without false replay-miss | TX scheduler | timeout/replay regression | Implemented M2 |
| EDU-LINK-001 | Project-defined | normal TX only when link is active | link manager + TX | V009 | Implemented |
| EDU-LINK-002 | Project-defined | unrecoverable replay failure latches fail-stop until administrative disable | link manager + TX | V015 | Implemented M2 |
| EDU-LINK-003 | Project-defined | administrative disable flushes reliability epoch before re-enable | TX/RX/replay buffer/model | V016 | Implemented M2/M3 |
| EDU-LINK-004 | Project-defined | reset destroys pre-reset outstanding reliability state and restarts sequence epoch | TX/RX/replay buffer/link manager | V008 | Implemented M3 |
| EDU-VER-001 | Project-defined | verification must cover error/state/backpressure interactions and fatal recovery observability | UVM coverage + SVA | seeded UVM regression | Implemented M3 |
| UCIE4-* | Future official source | reserved until an official public UCIe 4.0 release exists | TBD | TBD | Blocked on official release |
