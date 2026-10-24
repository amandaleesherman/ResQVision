"""ResQVision guidance engine.

The "brain" between the camera/vision step and the first-aid instructions
screen. It consumes an Observation (text + labels) and returns structured,
source-cited first-aid guidance.

Safety contract (see resqvision-guidance-engine-spec.md):
- The engine never looks at images.
- The engine only outputs text that exists in the curated knowledge base.
- No diagnosis, no medications, no dosages.
- Emergency ("call 911") guidance is always present and never blocked by a
  failure in analysis.
"""

__version__ = "0.1.0"
