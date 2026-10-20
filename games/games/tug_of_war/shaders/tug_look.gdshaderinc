// Tug of War's grade (ART_BIBLE §4: warm, sunlit timber, bark-brown shadows) on the 3D games'
// shared hand light (framework/shaders/world_look.gdshaderinc). Every Tug world shader includes
// this instead of the framework file, so the grade is set once.
#define LOOK_SAT 1.1
#define LOOK_CONTRAST 1.04
#define LOOK_GAIN vec3(1.04, 1.0, 0.94)
#define LOOK_LIFT vec3(0.03, 0.01, 0.0)
#define LOOK_VIGNETTE 0.3
#define LOOK_VIGNETTE_TINT vec3(1.0, 0.9, 0.8)
#include "res://framework/shaders/world_look.gdshaderinc"
