# Requirements Traceability

| Requirement ID | Source | Paraphrased requirement | RTL / model | Test | Status |
|---|---|---|---|---|---|
| EDU-REL-001 | Project-defined | corrupted data must not be delivered | `ucie_adapter_rx.sv` | V003/V004 | Implemented |
| EDU-REL-002 | Project-defined | retained flit can be replayed by sequence | TX + replay buffer | V003 | Implemented |
| EDU-REL-003 | Project-defined | selective ACK cannot cause overwrite of another live replay entry | `ucie_replay_buffer.sv` | V011 | Implemented M1 |
| EDU-REL-004 | Project-defined | a sequence ID still outstanding at wrap cannot be reallocated | TX + replay buffer/model | V010 | Implemented M1 |
| EDU-REL-005 | Project-defined | ACK-loss replay is acknowledged but not delivered twice | `ucie_adapter_rx.sv` | V012 | Implemented M1 |
| EDU-REL-006 | Project-defined | future/gap sequence requests the next expected sequence | `ucie_adapter_rx.sv` | V013 | Implemented M1 |
| EDU-REL-007 | Project-defined | repeated retry has a bounded budget | Python model | V006 | Model implemented; RTL M2 |
| EDU-LINK-001 | Project-defined | normal TX only when link is active | link manager + TX | V009 | Implemented |
| UCIE4-* | Future official source | reserved until an official public UCIe 4.0 release exists | TBD | TBD | Blocked on official release |
