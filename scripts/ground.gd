extends TileMapLayer

@onready var aboveground = $"../Aboveground"
@onready var aboveground2 = $"../Aboveground2"

func _use_tile_data_runtime_update(coords: Vector2i) -> bool:
	return aboveground.get_cell_source_id(coords) != -1 and aboveground2.get_cell_source_id(coords) != -1

func _tile_data_runtime_update(coords: Vector2i, tile_data: TileData) -> void:
	if aboveground.get_cell_source_id(coords) != -1:
		tile_data.set_collision_polygons_count(0, 0)
	if aboveground2.get_cell_source_id(coords) != -1:
		tile_data.set_collision_polygons_count(0, 0)
