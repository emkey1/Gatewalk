extends RefCounted
class_name ProgressionService

# The Cartographer's Kit.
#
# Discoveries earned across a universe unlock concrete, navigation-focused
# capabilities. Unlocks are a PURE FUNCTION of the cumulative discovery count,
# so player capability is fully derivable from existing save state — no new
# persisted capability fields and no save migration. The only thing the rest of
# the game persists is which unlock notifications have already been shown
# (universe.announced_upgrades), so a toast fires exactly once per upgrade.
#
# Capability values are ABSOLUTE per tier (not additive). capabilities() applies
# unlocked upgrades in threshold order, so the highest unlocked tier of each
# track wins. Base values mirror the constants in scripts/Player.gd.

const BASE_CAPS := {
	"max_breath": 60.0,             # Player.MAX_BREATH
	"max_sprint_stamina": 15.0,     # Player.MAX_SPRINT_STAMINA
	"sprint_regen_per_sec": 1.0 / 3.0,
	"max_flashlight_charge": 30.0,  # Player.FLASHLIGHT_MAX_CHARGE
	"flashlight_range_bonus": 0.0,
	"pin_cap": 6,
	"survey_radius": 0.0,           # bonus discovery auto-detect / minimap reveal radius
	"gate_sight": false,            # reveal the map type behind a gate before entering
}

# Ordered by threshold (ascending). Keep it sorted — next_upgrade relies on order.
const UPGRADE_DEFS: Array = [
	{"id": "strider_1", "track": "strider", "tier": 1, "name": "Strider I", "short": "Strider I",
		"desc": "Hardened legs — more sprint stamina and faster recovery.",
		"threshold": 3, "effect": {"max_sprint_stamina": 22.0, "sprint_regen_per_sec": 0.45}},
	{"id": "lungs_1", "track": "lungs", "tier": 1, "name": "Lungs I", "short": "Lungs I",
		"desc": "Trained breath — stay underwater longer.",
		"threshold": 6, "effect": {"max_breath": 90.0}},
	{"id": "lantern_1", "track": "lantern", "tier": 1, "name": "Lantern I", "short": "Lantern I",
		"desc": "Brighter, longer-lasting flashlight for caves.",
		"threshold": 10, "effect": {"max_flashlight_charge": 45.0, "flashlight_range_bonus": 6.0}},
	{"id": "pins_1", "track": "pins", "tier": 1, "name": "Pathfinder's Pins I", "short": "Pins I",
		"desc": "Carry more survey pins (cap 9).",
		"threshold": 15, "effect": {"pin_cap": 9}},
	{"id": "survey_1", "track": "survey", "tier": 1, "name": "Far Survey I", "short": "Survey I",
		"desc": "Wider survey reach — spot discoveries from farther away.",
		"threshold": 21, "effect": {"survey_radius": 8.0}},
	{"id": "lungs_2", "track": "lungs", "tier": 2, "name": "Lungs II", "short": "Lungs II",
		"desc": "Free-diver's lungs — much longer underwater.",
		"threshold": 28, "effect": {"max_breath": 130.0}},
	{"id": "lantern_2", "track": "lantern", "tier": 2, "name": "Lantern II", "short": "Lantern II",
		"desc": "Reinforced lamp — deeper cave runs.",
		"threshold": 36, "effect": {"max_flashlight_charge": 65.0, "flashlight_range_bonus": 12.0}},
	{"id": "strider_2", "track": "strider", "tier": 2, "name": "Strider II", "short": "Strider II",
		"desc": "Marathon legs — long sprints across open ground.",
		"threshold": 45, "effect": {"max_sprint_stamina": 30.0, "sprint_regen_per_sec": 0.6}},
	{"id": "gate_sight", "track": "gate_sight", "tier": 1, "name": "Gate Sight", "short": "Gate Sight",
		"desc": "Read a gate's shimmer — know the world type before you cross.",
		"threshold": 55, "effect": {"gate_sight": true}},
	{"id": "lungs_3", "track": "lungs", "tier": 3, "name": "Lungs III", "short": "Lungs III",
		"desc": "Abyssal lungs — explore the deep at leisure.",
		"threshold": 70, "effect": {"max_breath": 180.0}},
	{"id": "lantern_3", "track": "lantern", "tier": 3, "name": "Lantern III", "short": "Lantern III",
		"desc": "Beacon lamp — light the longest labyrinths.",
		"threshold": 85, "effect": {"max_flashlight_charge": 90.0, "flashlight_range_bonus": 18.0}},
	{"id": "pins_2", "track": "pins", "tier": 2, "name": "Pathfinder's Pins II", "short": "Pins II",
		"desc": "Full pin satchel (cap 14).",
		"threshold": 100, "effect": {"pin_cap": 14}},
	{"id": "survey_2", "track": "survey", "tier": 2, "name": "Far Survey II", "short": "Survey II",
		"desc": "Master surveyor's eye — spot discoveries at a distance.",
		"threshold": 120, "effect": {"survey_radius": 16.0}},
]


static func upgrade_by_id(id: String) -> Dictionary:
	for def in UPGRADE_DEFS:
		if str(def.get("id", "")) == id:
			return def
	return {}


static func unlocked(total: int) -> Array:
	var out: Array = []
	for def in UPGRADE_DEFS:
		if total >= int(def.get("threshold", 0)):
			out.append(def)
	return out


static func unlocked_ids(total: int) -> Array:
	var out: Array = []
	for def in unlocked(total):
		out.append(str(def.get("id", "")))
	return out


# Capabilities for a given cumulative discovery total. Absolute per-track values;
# higher unlocked tiers override lower ones because UPGRADE_DEFS is threshold-ordered.
static func capabilities(total: int) -> Dictionary:
	var caps: Dictionary = BASE_CAPS.duplicate(true)
	for def in UPGRADE_DEFS:
		if total < int(def.get("threshold", 0)):
			continue
		var effect: Dictionary = def.get("effect", {})
		for key in effect.keys():
			caps[key] = effect[key]
	return caps


# First upgrade not yet earned, or {} when everything is unlocked.
static func next_upgrade(total: int) -> Dictionary:
	for def in UPGRADE_DEFS:
		if total < int(def.get("threshold", 0)):
			return def
	return {}


# Upgrades whose threshold falls in (prev_total, new_total] — i.e. earned by this
# discovery delta. Used to fire a one-time toast.
static func newly_unlocked(prev_total: int, new_total: int) -> Array:
	var out: Array = []
	for def in UPGRADE_DEFS:
		var threshold: int = int(def.get("threshold", 0))
		if prev_total < threshold and new_total >= threshold:
			out.append(def)
	return out


# Compact one-line kit summary showing the highest tier earned per track,
# e.g. "Strider I · Lungs II · Lantern I". Empty string before the first unlock.
static func kit_summary(total: int) -> String:
	var best_per_track: Dictionary = {}
	for def in UPGRADE_DEFS:
		if total < int(def.get("threshold", 0)):
			continue
		var track: String = str(def.get("track", def.get("id", "")))
		var threshold: int = int(def.get("threshold", 0))
		var prev = best_per_track.get(track, null)
		if prev == null or threshold >= int(prev.get("threshold", 0)):
			best_per_track[track] = def
	# Preserve track order by first appearance in UPGRADE_DEFS.
	var seen: Dictionary = {}
	var parts: Array = []
	for def in UPGRADE_DEFS:
		var track: String = str(def.get("track", def.get("id", "")))
		if seen.has(track):
			continue
		if best_per_track.has(track):
			seen[track] = true
			parts.append(str(best_per_track[track].get("short", track)))
	return " · ".join(parts)
