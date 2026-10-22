// Cadence Karaoke's grade (ART_BIBLE.md §4) on the shared world look
// (framework/shaders/world_look.gdshaderinc: `vnoise`, `haze`, `grade`). Include this instead of
// the shared file. Two flavours:
//   - opaque surfaces (the tunnel, the portal): the full grade, contrast and the ink-violet lift
//     included;
//   - additive layers (rings, halos, sparks): define CADENCE_ADDITIVE first. They get only the
//     grade's linear parts (saturation and the vignette), so stacked layers still add up instead
//     of each one adding its own lift.
// `frozen` (0-1, eased by CadenceWorld) pulls the saturation down 40% while scoring is frozen.

uniform float frozen = 0.0;

#define LOOK_SAT (1.15 * (1.0 - 0.4 * frozen))
#ifndef CADENCE_ADDITIVE
#define LOOK_CONTRAST 1.1
#define LOOK_LIFT vec3(0.01, 0.0, 0.03)
#endif
#define LOOK_VIGNETTE 0.35
#define LOOK_VIGNETTE_TINT vec3(0.8, 0.7, 1.1)

#include "res://framework/shaders/world_look.gdshaderinc"
