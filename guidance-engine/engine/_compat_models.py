"""Minimal stdlib-only fallback for the subset of pydantic v2 used by
engine/models.py.

This exists ONLY so the engine and its tests can run in the offline sandbox
where pydantic cannot be pip-installed. On any normal machine pydantic is
installed (see requirements.txt) and this module is never imported.

Supported surface (matching how models.py uses pydantic):
  - class Model(BaseModel): annotated fields, optional `= Field(...)` defaults
  - Model(**data) constructor with validation + light coercion
  - field defaults, default_factory
  - numeric bound validation via Field(ge=, le=)
  - nested BaseModel fields and List[BaseModel]
  - .model_dump()  -> dict (recursively)
  - dict(model)    -> dict (so `Source(**s)` and `**model` work)
  - .__eq__ by field values
"""

from __future__ import annotations

import typing
from typing import Any, Dict, get_args, get_origin


class _Undefined:
    pass


_UNDEFINED = _Undefined()


class FieldInfo:
    def __init__(self, default=_UNDEFINED, default_factory=None, ge=None, le=None):
        self.default = default
        self.default_factory = default_factory
        self.ge = ge
        self.le = le


def Field(default=_UNDEFINED, *, default_factory=None, ge=None, le=None):
    return FieldInfo(default=default, default_factory=default_factory, ge=ge, le=le)


def _coerce(value, annotation, field_name):
    """Light coercion + validation for the annotations this module uses."""
    if annotation is None or annotation is type(None):
        return value

    origin = get_origin(annotation)

    # Optional[X] / Union — accept None, else coerce to the first non-None arg.
    if origin is typing.Union:
        args = [a for a in get_args(annotation) if a is not type(None)]
        if value is None:
            return None
        return _coerce(value, args[0], field_name) if args else value

    # List[X]
    if origin in (list, typing.List):
        (inner,) = get_args(annotation) or (Any,)
        if not isinstance(value, list):
            raise ValueError(f"{field_name}: expected a list")
        return [_coerce(v, inner, field_name) for v in value]

    # Literal[...] — value must be one of the allowed literals.
    if origin is typing.Literal:
        allowed = get_args(annotation)
        if value not in allowed:
            raise ValueError(f"{field_name}: {value!r} not in {allowed}")
        return value

    # Nested model
    if isinstance(annotation, type) and issubclass(annotation, BaseModel):
        if isinstance(value, annotation):
            return value
        if isinstance(value, dict):
            return annotation(**value)
        raise ValueError(f"{field_name}: expected {annotation.__name__} or dict")

    # Scalars
    if annotation is float and isinstance(value, int) and not isinstance(value, bool):
        return float(value)
    if annotation in (str, int, float, bool):
        if not isinstance(value, annotation):
            # Be lenient only for float<-int (handled above); otherwise error.
            raise ValueError(
                f"{field_name}: expected {annotation.__name__}, got "
                f"{type(value).__name__}"
            )
    return value


class _ModelMeta(type):
    def __new__(mcs, name, bases, ns):
        cls = super().__new__(mcs, name, bases, ns)
        # Collect raw annotations across the MRO (base first). These may be
        # strings because models.py uses `from __future__ import annotations`.
        raw: Dict[str, Any] = {}
        for base in reversed(cls.__mro__):
            for key, ann in getattr(base, "__annotations__", {}).items():
                # Skip private/dunder attributes (e.g. the __fields__ declared
                # on BaseModel itself) — only real model fields count.
                if key.startswith("_"):
                    continue
                raw[key] = ann
        # Defer resolution of string annotations until first use, because the
        # referenced classes may not all be defined yet at class-creation time.
        cls.__raw_fields__ = raw
        cls.__fields_resolved__ = False
        cls.__fields__ = dict(raw)
        return cls

    def _resolve_fields(cls):
        if cls.__fields_resolved__:
            return
        import sys

        module = sys.modules.get(cls.__module__)
        globalns = getattr(module, "__dict__", {})
        resolved: Dict[str, Any] = {}
        for field_name, annotation in cls.__raw_fields__.items():
            if isinstance(annotation, str):
                try:
                    annotation = eval(annotation, globalns, dict(vars(cls)))
                except Exception:
                    pass  # leave as-is; _coerce tolerates unknown annotations
            resolved[field_name] = annotation
        cls.__fields__ = resolved
        cls.__fields_resolved__ = True


class BaseModel(metaclass=_ModelMeta):
    __fields__: Dict[str, Any] = {}

    def __init__(self, **data):
        type(self)._resolve_fields()
        for field_name, annotation in self.__class__.__fields__.items():
            default = getattr(self.__class__, field_name, _UNDEFINED)

            if field_name in data:
                raw = data[field_name]
            elif isinstance(default, FieldInfo):
                if default.default_factory is not None:
                    raw = default.default_factory()
                elif default.default is not _UNDEFINED:
                    raw = default.default
                else:
                    raise ValueError(f"missing required field: {field_name}")
            elif default is not _UNDEFINED:
                raw = default
            else:
                raise ValueError(f"missing required field: {field_name}")

            coerced = _coerce(raw, annotation, field_name)

            # Field numeric bounds
            if isinstance(default, FieldInfo):
                if default.ge is not None and coerced < default.ge:
                    raise ValueError(f"{field_name}: must be >= {default.ge}")
                if default.le is not None and coerced > default.le:
                    raise ValueError(f"{field_name}: must be <= {default.le}")

            setattr(self, field_name, coerced)

    @staticmethod
    def _dump_value(value):
        if isinstance(value, BaseModel):
            return value.model_dump()
        if isinstance(value, list):
            return [BaseModel._dump_value(v) for v in value]
        return value

    def model_dump(self) -> Dict[str, Any]:
        return {
            name: self._dump_value(getattr(self, name))
            for name in self.__class__.__fields__
        }

    # Allow dict(model) and **model to work (used by Source(**s) patterns).
    def keys(self):
        return self.__class__.__fields__.keys()

    def __getitem__(self, key):
        return getattr(self, key)

    def __eq__(self, other):
        if not isinstance(other, BaseModel):
            return NotImplemented
        return self.model_dump() == other.model_dump()

    def __repr__(self):
        fields = ", ".join(
            f"{n}={getattr(self, n)!r}" for n in self.__class__.__fields__
        )
        return f"{self.__class__.__name__}({fields})"
