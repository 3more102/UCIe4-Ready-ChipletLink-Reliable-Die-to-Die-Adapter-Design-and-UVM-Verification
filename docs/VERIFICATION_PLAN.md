# Verification Plan

## Strategy

1. Python golden model for deterministic CRC, ordering, replay, wrap, duplicate, ACK timeout, retry budget, and administrative flush behavior.
2. Directed RTL smoke tests for corruption/replay, selective-ACK replay allocation, duplicate/order handling, timeout/exhaustion fail-stop, administrative disable, and reset with outstanding state.
3. UVM constrained-random source traffic with independent destination monitor and scoreboard.
4. SVA for link gating, transfer stability, error-to-retry, ACK/retry exclusivity, duplicate re-ACK, and fatal-fault latching.
5. Functional coverage through the UVM reliability collector and state/error/backpressure crosses.
6. Deterministic seeded Questa regression with per-seed logs and a machine-readable JSON summary.
7. Verilator lint and open-source directed regressions in GitHub Actions.

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
| V008 | reset during outstanding traffic | state cleared; no stale replay; new epoch starts at sequence 0 | reset smoke |
| V009 | link disable | no normal acceptance/transmit | SVA |
| V010 | sequence wrap | no aliasing of live entry | model/RTL guard |
| V011 | selective ACK hole | later push cannot overwrite another live replay entry | replay smoke |
| V012 | ACK-loss duplicate | re-ACK but no second protocol delivery | duplicate smoke/model |
| V013 | sequence gap | request exact next expected sequence | duplicate smoke/model |
| V014 | ACK timeout | automatically replay exact retained flit | timeout smoke/model |
| V015 | retry exhaustion | raise failing sequence, latch link fault, stop traffic | timeout smoke |
| V016 | administrative disable/re-enable | flush reliability epoch and clear link fault | disable smoke/model |

## Current automated evidence

GitHub Actions on the M3 branch runs:
- Python reference regression: **14 tests**
- directed Icarus regression: **6 smoke targets**
- Verilator RTL lint

The commercial-simulator UVM runner is intentionally separate from open-source CI. Run:

```bash
SEEDS="1 7 42 31415" ./scripts/run_questa_regression.sh
```

It writes per-seed logs and `reports/uvm/summary.json`.

## Exit criteria for a strong academic release

- all directed tests pass
- constrained-random regression has zero scoreboard mismatches
- all assertions pass
- planned functional coverage bins hit or explicitly waived
- synthesis report captured with area/Fmax
- measured clean-link latency and retry penalty reported
