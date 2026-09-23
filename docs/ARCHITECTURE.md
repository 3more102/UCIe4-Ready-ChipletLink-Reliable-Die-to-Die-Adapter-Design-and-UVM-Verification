# Architecture

## TX reliability path

1. Accept a protocol-side flit only when the link is active, replay storage has space, and the next sequence ID is not still outstanding.
2. Calculate the repository-defined CRC-32 over sequence + 256-bit payload.
3. Store `{seq,payload,crc}` in the replay buffer.
4. Retain the entry until the matching peer ACK is observed.
5. On peer retry, look up the requested sequence and resend the exact retained payload and CRC.
6. If sequence wrap reaches a still-live sequence ID, stall new acceptance rather than aliasing or overwriting the live replay entry.

The replay buffer allocates the first actual free slot. This avoids the classic selective-ACK bug where a wrapping write pointer can overwrite a different live entry after a hole is created.

## RX reliability path

The receiver tracks the next expected sequence.

- expected sequence + correct CRC: deliver once, ACK, increment expected sequence
- recent duplicate + correct CRC: ACK again, suppress delivery
- future/gap sequence + correct CRC: suppress delivery and request the exact expected sequence
- CRC mismatch: suppress delivery and request the exact expected sequence

CRC and sequence errors are reported to the link manager as recovery events.

## Link manager

States:
- RESET
- DISABLED
- INIT
- ACTIVE
- RECOVERY

The current FSM is deliberately compact. Automatic timeout escalation, richer link negotiation, power states, and health telemetry are later milestones.

## Current reliability boundary

M1 closes replay overwrite, sequence-wrap aliasing, duplicate delivery, and basic gap detection. The next major gap is automatic ACK timeout plus a bounded RTL retry budget.
