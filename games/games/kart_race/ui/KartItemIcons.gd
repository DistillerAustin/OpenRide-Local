class_name KartItemIcons
extends RefCounted
## The items' icons (#43), drawn in code on any CanvasItem: chunky shapes with a dark outline and
## a gloss highlight, in the HUD's sticker style. All original designs:
##
##   turbo   Turbo Can: an orange can with a lightning stripe
##   puck    Bumper Puck: a heavy striped puck, seen at an angle
##   drone   Seeker Drone: a round drone with twin rotors and a red eye
##   goo     Goo Puddle: a green blob with bubbles
##   shield  Shield Bubble: a glassy bubble with a ring
##   magnet  Draft Magnet: a horseshoe magnet with wind streaks
##
## The race-systems agent names the items; `kind()` maps any id to one of these by keyword, so a
## longer id ("turbo_can", "bumper_puck") draws the right icon.

const KINDS := ["turbo", "puck", "drone", "goo", "shield", "magnet"]
const OUTLINE := Color(0.13, 0.06, 0.24)


## One of KINDS for an item id, or "" when none matches.
static func kind(item_id: String) -> String:
	var id := item_id.to_lower()
	for k in KINDS:
		if id.contains(k):
			return k
	if id.contains("boost") or id.contains("can"):
		return "turbo"
	if id.contains("bubble"):
		return "shield"
	return ""


## Draws `item_id`'s icon centred at `c`, `r` px in radius (the icon fits a circle of r).
static func draw(ci: CanvasItem, item_id: String, c: Vector2, r: float) -> void:
	match kind(item_id):
		"turbo":
			_turbo(ci, c, r)
		"puck":
			_puck(ci, c, r)
		"drone":
			_drone(ci, c, r)
		"goo":
			_goo(ci, c, r)
		"shield":
			_shield(ci, c, r)
		"magnet":
			_magnet(ci, c, r)
		_:
			_unknown(ci, c, r)


static func _turbo(ci: CanvasItem, c: Vector2, r: float) -> void:
	var w := r * 0.95
	var h := r * 1.5
	var body := Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))
	round_rect(ci, body.grow(r * 0.08), r * 0.2, OUTLINE)
	round_rect(ci, body, r * 0.14, Color(1.0, 0.5, 0.12))
	# Rims top and bottom.
	round_rect(ci, Rect2(body.position + Vector2(0, -r * 0.04), Vector2(w, r * 0.2)), r * 0.08, Color(0.85, 0.86, 0.92))
	round_rect(ci, Rect2(body.position + Vector2(0, h - r * 0.16), Vector2(w, r * 0.2)), r * 0.08, Color(0.85, 0.86, 0.92))
	# A lightning stripe.
	var bolt := PackedVector2Array([
		c + Vector2(0.1, -0.5) * r, c + Vector2(-0.28, 0.06) * r, c + Vector2(-0.02, 0.06) * r,
		c + Vector2(-0.12, 0.52) * r, c + Vector2(0.3, -0.08) * r, c + Vector2(0.04, -0.08) * r])
	ci.draw_colored_polygon(bolt, Color(1.0, 0.95, 0.4))
	ci.draw_polyline(_closed(bolt), OUTLINE, r * 0.06, true)
	# Gloss.
	ci.draw_line(body.position + Vector2(w * 0.2, r * 0.3), body.position + Vector2(w * 0.2, h - r * 0.3), Color(1, 1, 1, 0.45), r * 0.09, true)


static func _puck(ci: CanvasItem, c: Vector2, r: float) -> void:
	var top := c + Vector2(0, -r * 0.18)
	var bottom := c + Vector2(0, r * 0.22)
	var rx := r * 0.92
	var ry := r * 0.42
	_ellipse(ci, bottom, rx + r * 0.08, ry + r * 0.08, OUTLINE)
	ci.draw_rect(Rect2(Vector2(c.x - rx - r * 0.08, top.y), Vector2((rx + r * 0.08) * 2.0, bottom.y - top.y)), OUTLINE)
	_ellipse(ci, top, rx + r * 0.08, ry + r * 0.08, OUTLINE)
	_ellipse(ci, bottom, rx, ry, Color(0.2, 0.22, 0.32))
	ci.draw_rect(Rect2(Vector2(c.x - rx, top.y), Vector2(rx * 2.0, bottom.y - top.y)), Color(0.2, 0.22, 0.32))
	# A yellow band round the side.
	ci.draw_rect(Rect2(Vector2(c.x - rx, top.y + (bottom.y - top.y) * 0.35), Vector2(rx * 2.0, (bottom.y - top.y) * 0.4)), Color(1.0, 0.8, 0.15))
	_ellipse(ci, top, rx, ry, Color(0.36, 0.4, 0.55))
	_ellipse(ci, top, rx * 0.55, ry * 0.55, Color(1.0, 0.8, 0.15))
	_ellipse(ci, top + Vector2(-rx * 0.35, -ry * 0.3), rx * 0.25, ry * 0.18, Color(1, 1, 1, 0.5))


static func _drone(ci: CanvasItem, c: Vector2, r: float) -> void:
	for side: float in [-1.0, 1.0]:
		var arm := c + Vector2(side * r * 0.68, -r * 0.42)
		ci.draw_line(c, arm, OUTLINE, r * 0.2, true)
		ci.draw_line(c, arm, Color(0.75, 0.78, 0.88), r * 0.1, true)
		_ellipse(ci, arm, r * 0.42, r * 0.13, OUTLINE)
		_ellipse(ci, arm, r * 0.36, r * 0.08, Color(0.85, 0.95, 1.0, 0.9))
	ci.draw_circle(c + Vector2(0, r * 0.12), r * 0.6, OUTLINE)
	ci.draw_circle(c + Vector2(0, r * 0.12), r * 0.52, Color(0.3, 0.75, 0.95))
	ci.draw_circle(c + Vector2(0, r * 0.2), r * 0.26, OUTLINE)
	ci.draw_circle(c + Vector2(0, r * 0.2), r * 0.2, Color(1.0, 0.25, 0.25))
	ci.draw_circle(c + Vector2(-r * 0.06, r * 0.13), r * 0.07, Color(1, 1, 1, 0.9))
	ci.draw_arc(c + Vector2(0, r * 0.12), r * 0.42, PI * 1.1, PI * 1.45, 10, Color(1, 1, 1, 0.55), r * 0.07, true)


static func _goo(ci: CanvasItem, c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		var wob := 1.0 + 0.12 * sin(a * 3.0 + 0.6) + 0.07 * sin(a * 5.0)
		pts.append(c + Vector2(cos(a) * r * 0.95, sin(a) * r * 0.62 + r * 0.12) * wob)
	var outline := PackedVector2Array()
	for p in pts:
		outline.append(c + (p - c) * 1.1)
	ci.draw_colored_polygon(outline, OUTLINE)
	ci.draw_colored_polygon(pts, Color(0.45, 0.85, 0.2))
	ci.draw_circle(c + Vector2(-r * 0.3, 0), r * 0.18, Color(0.7, 1.0, 0.45))
	ci.draw_circle(c + Vector2(r * 0.25, r * 0.22), r * 0.12, Color(0.7, 1.0, 0.45))
	ci.draw_circle(c + Vector2(r * 0.38, -r * 0.12), r * 0.08, Color(0.85, 1.0, 0.7))
	ci.draw_circle(c + Vector2(-r * 0.36, -r * 0.06), r * 0.06, Color(1, 1, 1, 0.8))


static func _shield(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c, r * 0.95, OUTLINE)
	ci.draw_circle(c, r * 0.87, Color(0.35, 0.8, 1.0, 0.95))
	ci.draw_circle(c, r * 0.66, Color(0.55, 0.9, 1.0, 0.95))
	ci.draw_arc(c, r * 0.87, 0, TAU, 40, Color(0.85, 0.98, 1.0), r * 0.08, true)
	ci.draw_arc(c, r * 0.6, PI * 1.05, PI * 1.5, 12, Color(1, 1, 1, 0.85), r * 0.12, true)
	ci.draw_circle(c + Vector2(r * 0.34, r * 0.34), r * 0.08, Color(1, 1, 1, 0.7))


static func _magnet(ci: CanvasItem, c: Vector2, r: float) -> void:
	var centre := c + Vector2(r * 0.12, -r * 0.08)
	var arc_r := r * 0.52
	ci.draw_arc(centre, arc_r, PI * 0.5, PI * 1.5, 24, OUTLINE, r * 0.52, true)
	ci.draw_arc(centre, arc_r, PI * 0.5, PI * 1.5, 24, Color(0.92, 0.2, 0.25), r * 0.36, true)
	for side: float in [-1.0, 1.0]:
		var y := centre.y + side * arc_r
		var leg := Rect2(Vector2(centre.x - r * 0.02, y - r * 0.18), Vector2(r * 0.62, r * 0.36))
		ci.draw_rect(leg.grow(r * 0.08), OUTLINE)
		ci.draw_rect(Rect2(leg.position, Vector2(leg.size.x * 0.55, leg.size.y)), Color(0.92, 0.2, 0.25))
		ci.draw_rect(Rect2(leg.position + Vector2(leg.size.x * 0.55, 0), Vector2(leg.size.x * 0.45, leg.size.y)), Color(0.88, 0.9, 0.96))
	ci.draw_arc(centre, arc_r, PI * 0.8, PI * 1.05, 8, Color(1, 1, 1, 0.5), r * 0.08, true)
	for i in 3:
		var y := c.y - r * 0.4 + i * r * 0.4
		ci.draw_line(Vector2(c.x - r * 1.0, y), Vector2(c.x - r * 0.62, y), Color(1, 1, 1, 0.85), r * 0.07, true)


static func _unknown(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c, r * 0.8, OUTLINE)
	ci.draw_circle(c, r * 0.7, Color(1.0, 0.8, 0.2))
	var font := KartTheme.display(true)
	var size := int(r * 1.1)
	var w := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string_outline(font, c + Vector2(-w * 0.5, size * 0.36), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(r * 0.12), OUTLINE)
	ci.draw_string(font, c + Vector2(-w * 0.5, size * 0.36), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)


static func _ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, color)


static func round_rect(ci: CanvasItem, rect: Rect2, radius: float, color: Color) -> void:
	radius = minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	ci.draw_rect(rect.grow_individual(-radius, 0, -radius, 0), color)
	ci.draw_rect(rect.grow_individual(0, -radius, 0, -radius), color)
	for corner in [rect.position + Vector2(radius, radius), Vector2(rect.end.x - radius, rect.position.y + radius),
			Vector2(rect.position.x + radius, rect.end.y - radius), rect.end - Vector2(radius, radius)]:
		ci.draw_circle(corner, radius, color)


static func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.append(pts[0])
	return out
