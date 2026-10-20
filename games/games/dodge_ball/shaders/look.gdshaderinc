// Dodge Ball's grade (ART_BIBLE.md §4) on the shared hand light, haze and grade
// (framework/shaders/world_look.gdshaderinc). Every Dodge world shader includes this file, so the
// grade lives in one place: change it here and in the art bible together.
#define LOOK_SAT 1.08
#define LOOK_CONTRAST 1.05
#define LOOK_GAIN vec3(0.99, 1.0, 1.03)
#define LOOK_LIFT vec3(0.0, 0.01, 0.03)
#define LOOK_VIGNETTE 0.25
#define LOOK_VIGNETTE_TINT vec3(0.85, 0.9, 1.05)
#include "res://framework/shaders/world_look.gdshaderinc"
