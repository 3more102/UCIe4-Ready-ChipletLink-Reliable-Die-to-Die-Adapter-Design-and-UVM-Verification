# Verification Plan

## Strategy

1. Python golden model for deterministic CRC, ordering, replay, wrap, duplicate, ACK timeout, retry budget, and administrative flush behavior.
2. Directed RTL smoke tests for corruption/replay, selective-ACK replay allocation, duplicate/order handling, and timeout/exhaustion fail-stop.
3. UVM constrained-random source traffic with independent destination monitor and scoreboard.
4. SVA for link gating, transfer stability, error-to-retry, ACK/retry exclusivity, and duplicate re-ACK behavior.
5. Functional coverage closure in M3.

## Test families

| ID | Test | Expected result | Current |
|---|---|---|---|
| V001 | clean single flit | delivered exactly once | smoke/UVM |
| V002 | clean burst | ordered, lossless delivery | UVM scaffold |
| V003 | data bit flip | CRC error, no bad delivery, retry, correct replay | smoke/UVM |
| V004 | CRC bit flip | CRC error, retry, correct replay | UVM |
| V005 | randomized backpressure | transfer stability and no loss | UVM |
| V006 | repeated retries | no replay beyond configured budget; explicit exhaustion | model + RTL smoke |
| V007 | replay buffer full | source backpressure, no overwrite | replay smoke |
| V008 | reset during traffic | state cleared; no ghost delivery | M3 |
| V009 | link disable | no normal acceptance/transmit | SVA |
| V010 | sequence wrap | no aliasing of live entry | model/RTL guard |
| V011 | selective ACK hole | later push cannot overwrite another live entry | replay smoke |
| V012 | ACK-loss duplicate | re-ACK but no second protocol delivery | duplicate smoke/model |
| V013 | sequence gap | request exact next expected sequence | duplicate smoke/model |
| V014 | ACK timeout | automatically replay exact retained flit | timeout smoke/model |
| V015 | retry exhaustion | raise failing sequence, latch link fault, stop traffic | timeout smoke |
| V016 | administrative disable/re-enable | flush reliability epoch and clear link fault | timeout smoke/model |

## Current evidence

GitHub Actions runs:
- Python reference regression: **14 tests**
- directed Icarus regression: **4 smoke targets**

The M2 code tree passed both jobs.

## Exit criteria for a strong academic release

- all directed tests pass
- constrained-random regression has zero scoreboard mismatches
- all assertions pass
- planned functional coverage bins hit or explicitly waived
- synthesis report captured with area/Fmax
- measured clean-link latency and retry penalty reported
