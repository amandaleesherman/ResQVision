"""Tests for the safety layer and the overall guidance safety invariants."""

from engine.guidance import get_guidance
from engine.models import Label, Observation
from engine.safety import (
    SAMPLE_LABEL,
    build_emergency,
    detect_red_flag,
    load_red_flags,
)


def _obs(description="", labels=None, is_sample=True, source="sample",
         uncertainties=None):
    return Observation(
        source=source,
        is_sample=is_sample,
        description=description,
        labels=labels or [],
        uncertainties=uncertainties or [],
    )


def test_red_flag_detected_in_description():
    rf = load_red_flags()
    call_911, reason = detect_red_flag(
        _obs(description="person is unconscious and not breathing"), rf
    )
    assert call_911 is True
    assert reason


def test_red_flag_detected_in_label():
    rf = load_red_flags()
    call_911, _ = detect_red_flag(
        _obs(description="arm", labels=[Label(name="spurting", confidence=0.9)]),
        rf,
    )
    assert call_911 is True


def test_no_red_flag_for_minor():
    rf = load_red_flags()
    call_911, _ = detect_red_flag(_obs(description="small scrape on knee"), rf)
    assert call_911 is False


def test_emergency_block_always_present():
    em_on = build_emergency(True, "Severe bleeding")
    em_off = build_emergency(False, None)
    assert em_on.call_911 is True and em_on.message
    assert em_off.call_911 is False and em_off.message


def test_sample_input_labeled_as_sample():
    resp = get_guidance(_obs(description="small cut", is_sample=True))
    assert resp.observation_provenance.label == SAMPLE_LABEL


def test_every_step_has_valid_source():
    resp = get_guidance(
        _obs(description="deep cut, blood soaking through, spurting",
             labels=[Label(name="bleeding", confidence=0.9)])
    )
    source_ids = {s.id for s in resp.sources}
    for step in resp.steps:
        assert step.source_id in source_ids


def test_disclaimer_and_emergency_always_present():
    for desc in ["", "garbage xyz", "deep cut spurting blood", "small scrape"]:
        resp = get_guidance(_obs(description=desc))
        assert resp.disclaimer
        assert resp.emergency is not None


def test_garbage_returns_fallback_not_error():
    resp = get_guidance(_obs(description="asdkjfh qwerty zzz"))
    assert resp.is_fallback
    assert resp.category == "general_unknown"


def test_uncertainties_passed_through():
    resp = get_guidance(
        _obs(description="deep cut spurting",
             uncertainties=["depth of wound cannot be determined"])
    )
    assert "depth of wound cannot be determined" in resp.cannot_determine


def test_red_flag_forces_call_911_even_on_fallback():
    # vague description but contains a red-flag term -> fallback + call_911
    resp = get_guidance(_obs(description="not sure, but chest pain and blue lips"))
    assert resp.emergency.call_911 is True
