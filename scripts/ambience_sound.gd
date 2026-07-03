extends AudioStreamPlayer

const WATER_ATLAS_COORDS := Vector2i(0, 13)
const MAX_SEARCH_TILES := 20

@export var max_volume_db: float = 5.0
@export var min_volume_db: float = -80.0
@export var max_distance: float = 250.0
@export var min_distance: float = 120.0

var distance_cache := {}

func _ready() -> void:
	stream = load("res://assets/sounds/wavescrashing.ogg")
	bake_ocean_distances()
	play()

func bake_ocean_distances() -> void:
	var ground := get_parent().get_parent().get_node("Ground") as TileMapLayer
	var above1 := get_parent().get_parent().get_node("Aboveground") as TileMapLayer
	var above2 := get_parent().get_parent().get_node("Aboveground2") as TileMapLayer

	var layers := [ground, above1, above2]

	# Union of every cell that exists on any layer
	var all_cells := {}
	for layer in layers:
		for cell in layer.get_used_cells():
			all_cells[cell] = true

	# A cell counts as water if ANY layer at that coord is flagged water
	var water_cells: Array[Vector2i] = []
	for cell in all_cells.keys():
		for layer in layers:
			var data = layer.get_cell_tile_data(cell)
			if data and data.get_custom_data("water"):
				water_cells.append(cell)
				break

	distance_cache.clear()
	for cell in all_cells.keys():
		if cell in water_cells:
			distance_cache[cell] = 0.0
			continue
		var closest := INF
		for water in water_cells:
			var d = (cell - water).length()
			if d < MAX_SEARCH_TILES:
				closest = minf(closest, d)
		distance_cache[cell] = closest

func _process(delta: float) -> void:
	var player_node := get_parent() as Node2D
	var tile_map = get_parent().get_parent().get_node("Ground") as TileMapLayer
	var cell := tile_map.local_to_map(player_node.global_position)
	var tile_dist: float = distance_cache.get(cell, MAX_SEARCH_TILES as float)
	var world_dist = tile_dist * tile_map.tile_set.tile_size.x
	var t := 1.0 - clampf((world_dist - min_distance) / (max_distance - min_distance), 0.0, 1.0)
	var target_db := lerpf(min_volume_db, max_volume_db, t)
	volume_db = lerpf(volume_db, target_db, delta * 2.0)
