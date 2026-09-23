#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPORT_DIR = ROOT / "reports" / "synth"


def load_yosys_json(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    start = text.find("{")
    end = text.rfind("}")
    if start < 0 or end < start:
        raise RuntimeError(f"no JSON object found in {path}")
    return json.loads(text[start : end + 1])


def extract(path: Path) -> dict:
    payload = load_yosys_json(path)
    modules = payload.get("modules", {})
    if not modules:
        raise RuntimeError(f"no module statistics found in {path}")
    name, stats = next(iter(modules.items()))
    return {
        "module": name.lstrip("\\"),
        "num_wires": stats.get("num_wires", 0),
        "num_wire_bits": stats.get("num_wire_bits", 0),
        "num_cells": stats.get("num_cells", 0),
        "num_cells_by_type": stats.get("num_cells_by_type", {}),
    }


def main() -> None:
    comb = extract(REPORT_DIR / "crc_comb.json")
    pipe = extract(REPORT_DIR / "crc_pipe.json")
    summary = {
        "schema_version": 1,
        "scope": "generic Yosys structural comparison of repository-defined CRC engines",
        "combinational": comb,
        "pipelined_one_stage": pipe,
        "timing_claim": None,
        "timing_note": (
            "No Fmax is claimed from this generic synthesis run. A defensible Fmax "
            "requires a named target technology/device, timing library, constraints, "
            "and a timing-capable implementation flow."
        ),
    }
    out = REPORT_DIR / "crc_compare_summary.json"
    out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(out.read_text(encoding="utf-8"), end="")


if __name__ == "__main__":
    main()
