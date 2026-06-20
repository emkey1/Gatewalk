extends RefCounted
class_name CreatureFactory

const MapContext = preload("res://scripts/core/MapContext.gd")

# Procedural species names for the bioscan catalog (No Man's Sky-style fauna logging).
const BIO_ADJECTIVES: Array[String] = [
	"Azure", "Crimson", "Pale", "Dusk", "Gilded", "Hollow", "Verdant", "Ashen",
	"Cobalt", "Amber", "Frosted", "Umber", "Opal", "Sable", "Ivory", "Russet",
	"Glass", "Storm", "Ember", "Mist", "Lunar", "Bramble", "Quartz", "Tidal",
]
const BIRD_NOUNS: Array[String] = [
	"Skimmer", "Glider", "Wing", "Drifter", "Lark", "Kite", "Soarer", "Veil", "Plume", "Crest",
]
const FISH_NOUNS: Array[String] = [
	"Finling", "Darter", "Gill", "Ripple", "Shoaler", "Eelet", "Glimmer", "Fluke", "Spine", "Tide",
]


static func creature_species_name(species_seed: int, is_bird: bool) -> String:
	var rng := StableRng.new(species_seed)
	var adjective: String = BIO_ADJECTIVES[rng.randi_range(0, BIO_ADJECTIVES.size() - 1)]
	var nouns: Array[String] = BIRD_NOUNS if is_bird else FISH_NOUNS
	var noun: String = nouns[rng.randi_range(0, nouns.size() - 1)]
	return adjective + " " + noun

static func scatter_birds(parent: Node3D, world_seed: int, context: MapContext) -> void:
	_scatter_birds_internal(
		parent,
		world_seed,
		Callable(context, "height_at_world"),
		context.world_half_size() * 0.88
	)


static func _scatter_birds_internal(parent: Node3D, world_seed: int, height_fn: Callable, half: float) -> void:
	var rng := StableRng.new(StableRng.mix_string(world_seed, "birds"))

	var placed := 0
	var attempts := 0
	while placed < 4 and attempts < 60:
		attempts += 1
		var x: float = rng.randf_range(-half, half)
		var z: float = rng.randf_range(-half, half)
		var y: float = height_fn.call(x, z)
		if y < -1.2:
			continue
		if Vector3(x, y, z).distance_to(Vector3.ZERO) < 60.0:
			continue

		var flock := preload("res://scripts/BirdFlock.gd").new()
		flock.name = "BirdFlock_" + str(placed)
		# Fly 8-18m above the local terrain (not an absolute height, which would put
		# flocks below high ground or floating islands).
		flock.position = Vector3(x, y + rng.randf_range(8.0, 18.0), z)
		var bird_seed: int = rng.next_u32()
		flock.set("rng_seed", bird_seed)
		flock.set("bird_count", rng.randi_range(8, 15))
		flock.set("species_name", creature_species_name(bird_seed, true))
		flock.set("catalog_id", "bio_bird_" + str(placed))
		parent.add_child(flock)
		placed += 1


static func scatter_fish(parent: Node3D, world_seed: int, context: MapContext) -> void:
	_scatter_fish_internal(
		parent,
		world_seed,
		Callable(context, "height_at_world"),
		context.world_half_size() * 0.88,
		context.water_level
	)


static func _scatter_fish_internal(parent: Node3D, world_seed: int, height_fn: Callable, half: float, water_level: float) -> void:
	var rng := StableRng.new(StableRng.mix_string(world_seed, "fish"))

	var placed := 0
	var target: int = 3
	var attempts := 0
	while placed < target and attempts < target * 15:
		attempts += 1
		var x: float = rng.randf_range(-half, half)
		var z: float = rng.randf_range(-half, half)
		var ground_y: float = height_fn.call(x, z)
		if ground_y > water_level - 0.2:
			continue
		if ground_y < water_level - 8.0:
			continue

		var school := preload("res://scripts/FishSchool.gd").new()
		school.name = "FishSchool_" + str(placed)
		var water_depth: float = water_level - ground_y
		var height_offset: float = rng.randf_range(0.3, 0.7)
		school.position = Vector3(x, ground_y + water_depth * height_offset, z)
		var fish_seed: int = rng.next_u32()
		school.set("rng_seed", fish_seed)
		school.set("fish_count", rng.randi_range(10, 18))
		school.set("species_name", creature_species_name(fish_seed, false))
		school.set("catalog_id", "bio_fish_" + str(placed))
		parent.add_child(school)
		placed += 1
