# Architecture

## TX reliability path

1. Accept a protocol-side flit only when the link is active, the TX path is not faulted, replay storage has space, and the next sequence ID is not still outstanding.
2. Calculate the repository-defined CRC-32 over sequence + 256-bit payload.
3. Store `{seq,payload,crc}` in the replay buffer with age=0 and retry_count=0.
4. Retain the entry until the matching peer ACK is observed.
5. On peer retry, look up the requested sequence and resend the exact retained payload and CRC.
6. If an ACK timer expires, automatically schedule the timed-out sequence for replay.
7. Every completed replay resets that entry's timer and increments its retry count.
8. If the next replay would exceed `MAX_RETRIES`, raise `retry_exhausted_o` with the offending sequence and enter fail-stop.
9. If sequence wrap reaches a still-live sequence ID, stall new acceptance rather than aliasing or overwriting the live replay entry.

The replay buffer allocates the first actual free slot. This avoids the selective-ACK bug where a wrapping write pointer can overwrite a different live entry after a hole is created.

### Replay races

A matching ACK cancels a pending replay before transmission. A timeout request that refers to a replay just completed in the same cycle is suppressed so the old saturated timer cannot immediately schedule a duplicate retry.

## RX reliability path

The receiver tracks the next expected sequence and an exact bounded history of accepted sequence IDs.

- expected sequence + correct CRC: deliver once, ACK, increment expected sequence, record the accepted sequence
- recent accepted duplicate + correct CRC: ACK again, suppress delivery
- future/gap sequence + correct CRC: suppress delivery and request the exact expected sequence
- CRC mismatch: suppress delivery and request the exact expected sequence

CRC and sequence errors are reported to the link manager as recoverable events.

## Link manager

States:
- RESET
- DISABLED
- INIT
- ACTIVE
- RECOVERY

Recoverable RX CRC/sequence events enter RECOVERY. TX replay miss or retry exhaustion is treated as fatal because the adapter can no longer prove lossless forward progress for the affected sequence. Fatal events latch `link_fault_o` and force DISABLED until the external controller deasserts `link_enable_i`.

## Administrative flush and reset

Deasserting `link_enable_i`:
- clears the latched link fault
- flushes replay entries/timers/retry counters
- resets the TX sequence epoch to 0
- resets the RX expected sequence/history to 0/empty
- clears held RX data

Asserting `rst_n=0` clears the same reliability state. Directed regressions verify that an unacknowledged pre-reset or pre-disable flit cannot replay into the new reliability epoch.

## Performance observability — M4-A

`ucie_perf_counters.sv` provides synthesizable saturating counters for:

- active link cycles
- accepted protocol-side TX flits
- completed RDI TX transfers
- protocol-side RX deliveries
- local or peer retry requests
- CRC/sequence/fatal reliability error events
- RDI TX stall cycles

The counters reset only with `rst_n`; administrative link disable does not erase them. This preserves cumulative observability across reliability epochs while reset starts a fresh measurement interval.

The distinction between protocol-side accepts and RDI transfers intentionally exposes reliability overhead. A replay increases RDI transfers without increasing protocol-side accepts, allowing replay overhead to be measured directly. Stall cycles expose downstream backpressure pressure on the transmitted flit stream.

## Current implementation boundary

M1 closes replay overwrite, sequence-wrap aliasing, duplicate delivery, and sequence-gap detection.

M2 closes indefinite outstanding traffic caused by lost ACKs with automatic timeout replay, a bounded retry budget, and explicit fail-stop behavior.

M3 closes verification observability with exact duplicate history, reset/disable regressions, UVM coverage, stronger SVA, deterministic seeds, machine-readable regression summaries, and Verilator lint.

M4-A adds synthesizable performance counters and directed evidence that clean transfers, backpressure stalls, retry requests, and replay overhead are counted consistently. Pipelined CRC and synthesis/area/Fmax characterization remain future M4 work.
