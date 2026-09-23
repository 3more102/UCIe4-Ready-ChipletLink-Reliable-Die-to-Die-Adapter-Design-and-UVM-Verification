# Synthesis evidence

## Current automated boundary

The open-source CI synthesizes the repository-defined CRC datapath in two forms:

- combinational
- one-stage registered/pipelined

Run:

```bash
make synth
```

The command writes machine-readable structural reports under `reports/synth/`.

The CRC smoke test independently compares both implementations against the package-level CRC reference used by the adapter, so synthesis measurements are tied to the same bit-level algorithm exercised by RTL verification.

## Why full-adapter Yosys synthesis is not a CI gate yet

The Ubuntu CI image currently provides Yosys 0.33. Its native SystemVerilog frontend does not accept the package-qualified port declarations used by the full adapter (for example, `ucie_adapter_pkg::link_state_e` and package-qualified width expressions).

Those constructs are valid SystemVerilog and are already checked by Verilator and Icarus/Questa-oriented flows. Rather than rewriting the design around an old frontend limitation or claiming unsupported synthesis evidence, full-adapter Yosys synthesis remains an explicit experimental target:

```bash
make synth-full-experimental
```

A future implementation phase can add a package-capable synthesis frontend or a technology-specific synthesis flow.

## Timing claims

The generic Yosys reports are structural area proxies only. They do **not** establish Fmax.

A defensible Fmax result requires:

- a named FPGA or standard-cell technology,
- a timing library/device database,
- clock and I/O constraints,
- and a timing-capable synthesis/place-and-route flow.

Until those inputs are selected, the repository intentionally records no Fmax claim.
