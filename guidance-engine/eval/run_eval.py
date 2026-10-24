"""Run the evaluation cases and write eval_results.json (spec Section 10).

Metrics:
  category_accuracy        top category matches expected          target >= 85%
  red_flag_recall          all expected 911 cases flagged         target 100%
  citation_coverage        every step has a valid source          target 100%
  fallback_correctness     vague cases fall back, not guess       target >= 90%
  unsupported_text_rate    steps not found verbatim in KB         target 0%
  sample_label_correctness sample inputs labeled as sample        target 100%

Also writes a per-case table for the safety dashboard.

Run:  python eval/run_eval.py   (from the guidance-engine/ directory)
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

# Make the package importable when run as a script from guidance-engine/.
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from engine.guidance import get_guidance  # noqa: E402
from engine.models import Observation  # noqa: E402
from engine.retrieve import load_knowledge_base  # noqa: E402
from engine.safety import SAMPLE_LABEL  # noqa: E402

CASES_PATH = ROOT / "data" / "eval_cases.json"
RESULTS_PATH = ROOT / "eval" / "eval_results.json"


def _kb_step_texts() -> set:
    """All step texts present in the KB (to check steps are not invented)."""
    kb = load_knowledge_base()
    texts = set()
    for entry in kb:
        for step in entry.get("steps", []):
            texts.add(step["text"])
    return texts


def run() -> dict:
    with open(CASES_PATH, "r", encoding="utf-8") as fh:
        cases = json.load(fh)["cases"]

    kb_texts = _kb_step_texts()

    rows = []
    n = len(cases)
    category_hits = 0
    red_flag_total = 0
    red_flag_hits = 0
    citation_ok = 0
    fallback_total = 0
    fallback_hits = 0
    unsupported_steps = 0
    total_steps = 0
    sample_total = 0
    sample_ok = 0

    for case in cases:
        obs = Observation(**case["observation"])
        resp = get_guidance(obs)

        exp_cat = case["expected_category"]
        exp_911 = case["expect_call_911"]
        exp_fb = case["expect_fallback"]

        cat_pass = resp.category == exp_cat
        category_hits += int(cat_pass)

        if exp_911:
            red_flag_total += 1
            red_flag_hits += int(resp.emergency.call_911)
        call_911_pass = resp.emergency.call_911 == exp_911

        # citation coverage: every step source_id exists in sources
        source_ids = {s.id for s in resp.sources}
        case_citation_ok = all(s.source_id in source_ids for s in resp.steps)
        citation_ok += int(case_citation_ok)

        if exp_fb:
            fallback_total += 1
            fallback_hits += int(resp.is_fallback)
        fb_pass = resp.is_fallback == exp_fb

        # unsupported text: step text must appear verbatim in the KB
        for s in resp.steps:
            total_steps += 1
            if s.text not in kb_texts:
                unsupported_steps += 1

        # sample labeling
        if obs.is_sample or obs.source == "sample":
            sample_total += 1
            sample_ok += int(resp.observation_provenance.label == SAMPLE_LABEL)

        rows.append(
            {
                "id": case["id"],
                "description": obs.description,
                "expected_category": exp_cat,
                "actual_category": resp.category,
                "expected_call_911": exp_911,
                "actual_call_911": resp.emergency.call_911,
                "expected_fallback": exp_fb,
                "actual_fallback": resp.is_fallback,
                "match_confidence": resp.match_confidence,
                "category_pass": cat_pass,
                "call_911_pass": call_911_pass,
                "citation_pass": case_citation_ok,
                "fallback_pass": fb_pass,
                "pass": cat_pass and call_911_pass and case_citation_ok and fb_pass,
            }
        )

    def pct(num, den):
        return round(100.0 * num / den, 1) if den else 100.0

    metrics = {
        "category_accuracy": pct(category_hits, n),
        "red_flag_recall": pct(red_flag_hits, red_flag_total),
        "citation_coverage": pct(citation_ok, n),
        "fallback_correctness": pct(fallback_hits, fallback_total),
        "unsupported_text_rate": pct(unsupported_steps, total_steps),
        "sample_label_correctness": pct(sample_ok, sample_total),
    }

    results = {
        "engine_version": resp.engine_version,
        "total_cases": n,
        "metrics": metrics,
        "targets": {
            "category_accuracy": ">= 85",
            "red_flag_recall": "100",
            "citation_coverage": "100",
            "fallback_correctness": ">= 90",
            "unsupported_text_rate": "0",
            "sample_label_correctness": "100",
        },
        "cases": rows,
    }
    return results


def main() -> None:
    results = run()
    with open(RESULTS_PATH, "w", encoding="utf-8") as fh:
        json.dump(results, fh, indent=2)

    m = results["metrics"]
    print(f"Ran {results['total_cases']} cases. Metrics:")
    for key, val in m.items():
        print(f"  {key:26s} {val}%")
    print(f"\nWrote {RESULTS_PATH}")


if __name__ == "__main__":
    main()
