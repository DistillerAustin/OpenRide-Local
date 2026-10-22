class_name KartItemIcons
extends RefCounted
## The items' icons (#43), drawn in code into a KartDraw (one draw call with the rest of the
## item button): chunky shapes with a dark outline and a gloss highlight, in the HUD's sticker
## style. All original designs:
##
##   turbo   Turbo Can: an orange can with a lightning stripe
##   puck    Bumper Puck: a heavy striped puck, seen at an angle
##   drone   Seeker Drone: a round drone with twin rotors and a red eye
##   goo     Goo Puddle: a green blob with bubbles
##   shield  Shield Bubble: a glassy bubble with a ring
##   magnet  Draft Magnet: a horseshoe magnet with wind streaks
##
## The race-systems agent names the items; `kind()` maps any id to one of these by keyword, so a
## longer id ("turbo_can", "bumper_puck") draws the right icon. Unknown ids draw a "?" token.

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


## Draws `item_id`'s icon centred at `c`, `r` px in radius. Returns false for an unknown id (the
## caller then draws its "?").
static func draw(d: KartDraw, item_id: String, c: Vector2, r: float) -> bool:
	match kind(item_id):
		"turbo":
			_turbo(d, c, r)
		"puck":
			_puck(d, c, r)
		"drone":
			_drone(d, c, r)
		"goo":
			_goo(d, c, r)
		"shield":
			_shield(d, c, r)
		"magnet":
			_magnet(d, c, r)
		_:
			d.disc(c, r * 0.8, OUTLINE)
			d.disc(c, r * 0.7, Color(1.0, 0.8, 0.2))
			return false
	return true


static func _turbo(d: KartDraw, c: Vector2, r: float) -> void:
	var w := r * 0.95
	var h := r * 1.5
	var body := Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))
	d.rect(body.grow(r * 0.08), OUTLINE, r * 0.2)
	d.rect(body, Color(1.0, 0.5, 0.12), r * 0.14)
	var rim := Color(0.85, 0.86, 0.92)
	d.rect(Rect2(body.position + Vector2(0, -r * 0.04), Vector2(w, r * 0.2)), rim, r * 0.08)
	d.rect(Rect2(body.position + Vector2(0, h - r * 0.16), Vector2(w, r * 0.2)), rim, r * 0.08)
	var bolt := PackedVector2Array([
		c + Vector2(0.1, -0.5) * r, c + Vector2(-0.28, 0.06) * r, c + Vector2(-0.02, 0.06) * r,
		c + Vector2(-0.12, 0.52) * r, c + Vector2(0.3, -0.08) * r, c + Vector2(0.04, -0.08) * r])
	d.polyline(_closed(bolt), r * 0.1, OUTLINE)
	d.polygon(bolt, Color(1.0, 0.95, 0.4))
	d.line(body.position + Vector2(w * 0.2, r * 0.3), body.position + Vector2(w * 0.2, h - r * 0.3), r * 0.09, Color(1, 1, 1, 0.45))


static func _puck(d: KartDraw, c: Vector2, r: float) -> void:
	var top := c + Vector2(0, -r * 0.18)
	var bottom := c + Vector2(0, r * 0.22)
	var rx := r * 0.92
	var ry := r * 0.42
	var o := r * 0.08
	d.ellipse(bottom, rx + o, ry + o, OUTLINE)
	d.rect(Rect2(Vector2(c.x - rx - o, top.y), Vector2((rx + o) * 2.0, bottom.y - top.y)), OUTLINE)
	d.ellipse(top, rx + o, ry + o, OUTLINE)
	var side := Color(0.2, 0.22, 0.32)
	d.ellipse(bottom, rx, ry, side)
	d.rect(Rect2(Vector2(c.x - rx, top.y), Vector2(rx * 2.0, bottom.y - top.y)), side)
	d.rect(Rect2(Vector2(c.x - rx, top.y + (bottom.y - top.y) * 0.35), Vector2(rx * 2.0, (bottom.y - top.y) * 0.4)), Color(1.0, 0.8, 0.15))
	d.ellipse(top, rx, ry, Color(0.36, 0.4, 0.55))
	d.ellipse(top, rx * 0.55, ry * 0.55, Color(1.0, 0.8, 0.15))
	d.ellipse(top + Vector2(-rx * 0.35, -ry * 0.3), rx * 0.25, ry * 0.18, Color(1, 1, 1, 0.5))


static func _drone(d: KartDraw, c: Vector2, r: float) -> void:
	for side: float in [-1.0, 1.0]:
		var arm := c + Vector2(side * r * 0.68, -r * 0.42)
		d.line(c, arm, r * 0.2, OUTLINE)
		d.line(c, arm, r * 0.1, Color(0.75, 0.78, 0.88))
		d.ellipse(arm, r * 0.42, r * 0.13, OUTLINE)
		d.ellipse(arm, r * 0.36, r * 0.08, Color(0.85, 0.95, 1.0, 0.9))
	var body := c + Vector2(0, r * 0.12)
	d.disc(body, r * 0.6, OUTLINE)
	d.disc(body, r * 0.52, Color(0.3, 0.75, 0.95))
	d.disc(c + Vector2(0, r * 0.2), r * 0.26, OUTLINE)
	d.disc(c + Vector2(0, r * 0.2), r * 0.2, Color(1.0, 0.25, 0.25))
	d.disc(c + Vector2(-r * 0.06, r * 0.13), r * 0.07, Color(1, 1, 1, 0.9))
	d.ring(body, r * 0.38, r * 0.45, Color(1, 1, 1, 0.55), Color(-1, 0, 0), PI * 1.1, PI * 1.45)


static func _goo(d: KartDraw, c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	var outline := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		var wob := 1.0 + 0.12 * sin(a * 3.0 + 0.6) + 0.07 * sin(a * 5.0)
		var p := c + Vector2(cos(a) * r * 0.95, sin(a) * r * 0.62 + r * 0.12) * wob
		pts.append(p)
		outline.append(c + (p - c) * 1.1)
	d.polygon(outline, OUTLINE)
	d.polygon(pts, Color(0.45, 0.85, 0.2))
	d.disc(c + Vector2(-r * 0.3, 0), r * 0.18, Color(0.7, 1.0, 0.45))
	d.disc(c + Vector2(r * 0.25, r * 0.22), r * 0.12, Color(0.7, 1.0, 0.45))
	d.disc(c + Vector2(r * 0.38, -r * 0.12), r * 0.08, Color(0.85, 1.0, 0.7))
	d.disc(c + Vector2(-r * 0.36, -r * 0.06), r * 0.06, Color(1, 1, 1, 0.8))


static func _shield(d: KartDraw, c: Vector2, r: float) -> void:
	d.disc(c, r * 0.95, OUTLINE)
	d.disc(c, r * 0.87, Color(0.35, 0.8, 1.0, 0.95))
	d.disc(c, r * 0.66, Color(0.55, 0.9, 1.0, 0.95))
	d.ring(c, r * 0.8, r * 0.88, Color(0.85, 0.98, 1.0))
	d.ring(c, r * 0.52, r * 0.64, Color(1, 1, 1, 0.85), Color(-1, 0, 0), PI * 1.05, PI * 1.5)
	d.disc(c + Vector2(r * 0.34, r * 0.34), r * 0.08, Color(1, 1, 1, 0.7))


static func _magnet(d: KartDraw, c: Vector2, r: float) -> void:
	var centre := c + Vector2(r * 0.12, -r * 0.08)
	var arc_r := r * 0.52
	d.ring(centre, arc_r - r * 0.26, arc_r + r * 0.26, OUTLINE, Color(-1, 0, 0), PI * 0.5, PI * 1.5)
	d.ring(centre, arc_r - r * 0.18, arc_r + r * 0.18, Color(0.92, 0.2, 0.25), Color(-1, 0, 0), PI * 0.5, PI * 1.5)
	for side: float in [-1.0, 1.0]:
		var y := centre.y + side * arc_r
		var leg := Rect2(Vector2(centre.x - r * 0.02, y - r * 0.18), Vector2(r * 0.62, r * 0.36))
		d.rect(leg.grow(r * 0.08), OUTLINE)
		d.rect(Rect2(leg.position, Vector2(leg.size.x * 0.55, leg.size.y)), Color(0.92, 0.2, 0.25))
		d.rect(Rect2(leg.position + Vector2(leg.size.x * 0.55, 0), Vector2(leg.size.x * 0.45, leg.size.y)), Color(0.88, 0.9, 0.96))
	d.ring(centre, arc_r - r * 0.04, arc_r + r * 0.04, Color(1, 1, 1, 0.5), Color(-1, 0, 0), PI * 0.8, PI * 1.05)
	for i in 3:
		var y := c.y - r * 0.4 + i * r * 0.4
		d.line(Vector2(c.x - r * 1.0, y), Vector2(c.x - r * 0.62, y), r * 0.07, Color(1, 1, 1, 0.85))


static func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.append(pts[0])
	return out
