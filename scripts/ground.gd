extends TileMapLayer

@onready var aboveground: TileMapLayer = $"../Aboveground"
@onready var aboveground2: TileMapLayer = $"../Aboveground2"

func _use_tile_data_runtime_update(coords: Vector2i) -> bool:
	return aboveground.get_cell_source_id(coords) != -1 or aboveground2.get_cell_source_id(coords) != -1

func _tile_data_runtime_update(coords: Vector2i, tile_data: TileData) -> void:
	if aboveground.get_cell_source_id(coords) != -1:
		tile_data.set_collision_polygons_count(0, 0)
		tile_data.set_custom_data("water", aboveground.get_cell_tile_data(coords).get_custom_data("water"))
		tile_data.set_custom_data("location", aboveground.get_cell_tile_data(coords).get_custom_data("location"))
	if aboveground2.get_cell_source_id(coords) != -1:
		tile_data.set_collision_polygons_count(0, 0)
		tile_data.set_custom_data("water", aboveground2.get_cell_tile_data(coords).get_custom_data("water"))
		tile_data.set_custom_data("location", aboveground2.get_cell_tile_data(coords).get_custom_data("location"))
