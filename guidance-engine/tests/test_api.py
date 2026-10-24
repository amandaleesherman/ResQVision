"""Tests for the FastAPI endpoints using the spec Section 5 examples."""

import pytest

# FastAPI (and its TestClient) are pinned in requirements.txt and available on
# a normal machine. In the offline sandbox they cannot be installed, so these
# HTTP-layer tests are skipped there. The core engine is covered by
# test_retrieve.py and test_safety.py, which run everywhere.
pytest.importorskip("fastapi", reason="fastapi not installed (offline sandbox)")

from fastapi.testclient import TestClient  # noqa: E402

from api.main import app  # noqa: E402

client = TestClient(app)


def test_health():
    r = client.get("/health")
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "ok"
    assert body["kb_entries"] >= 10


def test_categories():
    r = client.get("/categories")
    assert r.status_code == 200
    cats = r.json()["categories"]
    ids = {c["id"] for c in cats}
    assert "severe_bleeding" in ids
    assert "general_unknown" in ids


def test_guidance_section_5_example():
    # The exact input shape from Section 5.3 of the spec.
    observation = {
        "source": "vision_model",
        "is_sample": False,
        "description": "Open cut on left forearm, bright red blood flowing steadily, blood soaking through cloth",
        "labels": [
            {"name": "laceration", "confidence": 0.82},
            {"name": "bleeding", "confidence": 0.91},
        ],
        "body_location": "forearm",
        "uncertainties": [
            "depth of wound cannot be determined",
            "cannot see if object is embedded",
        ],
    }
    r = client.post("/guidance", json=observation)
    assert r.status_code == 200
    body = r.json()

    # Schema-level invariants
    assert "emergency" in body and "call_911" in body["emergency"]
    assert body["emergency"]["call_911"] is True  # "soaking through" red flag
    assert body["category"] == "severe_bleeding"
    assert body["disclaimer"]
    assert body["engine_version"]

    # citation coverage
    source_ids = {s["id"] for s in body["sources"]}
    for step in body["steps"]:
        assert step["source_id"] in source_ids

    # uncertainties passed through
    assert "depth of wound cannot be determined" in body["cannot_determine"]


def test_guidance_empty_returns_fallback():
    observation = {"source": "user_text", "is_sample": False, "description": "", "labels": []}
    r = client.post("/guidance", json=observation)
    assert r.status_code == 200
    body = r.json()
    assert body["is_fallback"] is True
    assert body["category"] == "general_unknown"
    assert "emergency" in body  # emergency block still present


def test_guidance_sample_is_labeled():
    observation = {"source": "sample", "is_sample": True, "description": "small cut on finger", "labels": []}
    r = client.post("/guidance", json=observation)
    body = r.json()
    assert "SAMPLE DATA" in body["observation_provenance"]["label"]


def test_eval_endpoint_returns_json():
    r = client.get("/eval")
    assert r.status_code == 200
    # Either not_run or a results payload — both are valid JSON objects.
    assert isinstance(r.json(), dict)
