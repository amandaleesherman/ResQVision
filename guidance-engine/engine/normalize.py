"""Text normalization and synonym expansion for retrieval.

Keeps things deterministic and dependency-free (standard library only).
Normalization is used for matching only; it never changes the text that is
returned to the user (that always comes verbatim from the knowledge base).
"""

from __future__ import annotations

import re
from typing import List

# Synonym map: phrase found in input -> canonical phrase used by KB keywords.
# Keep these conservative and non-medical (plain-language equivalents only).
SYNONYMS = {
    "gash": "deep cut",
    "laceration": "deep cut",
    "scald": "burn",
    "blister": "burn",
    "nose bleed": "nosebleed",
    "bleeding nose": "nosebleed",
    "broken bone": "fracture",
    "twisted ankle": "sprain",
    "bee sting": "sting",
    "wasp sting": "sting",
    "dog bite": "bite",
    "passed out": "unconscious",
    "knocked out": "unconscious",
    "not awake": "unresponsive",
    "can't breathe": "trouble breathing",
    "cannot breathe": "trouble breathing",
}

_APOSTROPHE_RE = re.compile(r"['\u2019]")  # straight and curly apostrophes
_PUNCT_RE = re.compile(r"[^\w\s]")
_WS_RE = re.compile(r"\s+")


def normalize_text(text: str) -> str:
    """Lowercase, strip punctuation, collapse whitespace, expand synonyms.

    Multi-word synonyms are expanded before single-word cleanup so phrases
    like "nose bleed" map correctly.
    """
    if not text:
        return ""
    lowered = text.lower()
    # Remove apostrophes so contractions collapse ("won't" -> "wont") instead
    # of splitting into two tokens ("won t"). Done on both the input text and
    # the red-flag/keyword terms, so matching stays symmetric.
    lowered = _APOSTROPHE_RE.sub("", lowered)
    # Expand multi-word synonyms first (on the cleaned lowercased string).
    for phrase, canonical in SYNONYMS.items():
        if phrase in lowered:
            lowered += " " + canonical
    cleaned = _PUNCT_RE.sub(" ", lowered)
    cleaned = _WS_RE.sub(" ", cleaned).strip()
    return cleaned


def normalize_labels(label_names: List[str]) -> List[str]:
    """Normalize a list of label names the same way as free text."""
    return [normalize_text(name) for name in label_names if name]
