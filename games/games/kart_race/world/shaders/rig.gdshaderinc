// The karts' rig (#43), shared by the kart and outline passes: every vertex carries its bone in
// UV2.x, and KartView sets each bone's skinning matrix (pose x inverse rest, kart space) every
// frame. Rigid, one bone a vertex: cheaper on the tablet than the engine's skeleton deform,
// which re-skins every posed mesh in a separate pass (about 0.2 ms a kart on the desktop).
// Unrigged meshes (portraits) leave `rigged` off.
uniform bool rigged = false;
uniform mat4 bones[12];

void rig(inout vec3 vertex, inout vec3 normal, vec2 uv2) {
	if (rigged) {
		mat4 m = bones[int(uv2.x + 0.5)];
		vertex = (m * vec4(vertex, 1.0)).xyz;
		normal = normalize(mat3(m) * normal);
	}
}
