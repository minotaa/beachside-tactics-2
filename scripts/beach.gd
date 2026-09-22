extends Level

const FISH_SHADOW_SCENE := preload("res://scenes/fish_shadow.tscn")

var baked_water_cells: Array[Vector2i] = []
var active_fish_shadows: Array[Node2D] = []

func _ready() -> void:
	bake_water_tiles()
	$CanvasModulate.visible = true

func _process(_delta: float) -> void:	
	$CanvasModulate.color = Game.get_sky_color()

func bake_water_tiles() -> void:
	var ground := $Ground as TileMapLayer
	var above1 := $Aboveground as TileMapLayer
	var above2 := $Aboveground2 as TileMapLayer

	var all_cells := {}
	for cell in ground.get_used_cells():
		all_cells[cell] = true
	for cell in above1.get_used_cells():
		all_cells[cell] = true
	for cell in above2.get_used_cells():
		all_cells[cell] = true

	baked_water_cells.clear()
	for cell in all_cells.keys():
		if above1.get_cell_source_id(cell) != -1 or above2.get_cell_source_id(cell) != -1:
			continue

		var data := ground.get_cell_tile_data(cell)
		if data and data.get_custom_data("water"):
			baked_water_cells.append(cell)

func spawn_fish_shadows(center: Vector2, radius: float, count: int = 15, min_spacing: float = 48.0, max_attempts_per_shadow: int = 30) -> void:
	if baked_water_cells.is_empty():
		return

	var ground := $Ground as TileMapLayer
	var candidate_cells: Array[Vector2i] = []
	for cell in baked_water_cells:
		var world_pos = ground.map_to_local(cell)
		if world_pos.distance_to(center) <= radius:
			candidate_cells.append(cell)

	if candidate_cells.is_empty():
		return

	var placed_positions: Array[Vector2] = []
	var placed_count := 0
	var total_attempts := 0
	var max_total_attempts := count * max_attempts_per_shadow

	while placed_count < count and total_attempts < max_total_attempts:
		total_attempts += 1
		var cell = candidate_cells[randi() % candidate_cells.size()]
		var world_pos = ground.map_to_local(cell)

		var too_close := false
		for existing in placed_positions:
			if existing.distance_to(world_pos) < min_spacing:
				too_close = true
				break
		if too_close:
			continue

		placed_positions.append(world_pos)
		placed_count += 1

	if not placed_positions.is_empty():
		Network.request_fish_shadow_items.rpc_id(1, Game.Location.Crystalwater_Ocean, placed_positions)
	
func clear_fish_shadows() -> void:
	for shadow in active_fish_shadows:
		if is_instance_valid(shadow):
			shadow.queue_free()
	active_fish_shadows.clear()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("players") and Game.get_player() != null and body == Game.get_player():
		body.do_slight_glitch()

func _on_void_music_body_entered(body: Node2D) -> void:
	if body.is_in_group("players") and Game.get_player() != null and body == Game.get_player():
		Game.play_music("res://assets/sounds/VoidFishing.wav", -10)
		var sfx_idx := AudioServer.get_bus_index("SFX")
		var tween := create_tween()
		tween.tween_method(func(db): AudioServer.set_bus_volume_db(sfx_idx, db), AudioServer.get_bus_volume_db(sfx_idx), -15.0, 1.0)

func _on_void_music_body_exited(body: Node2D) -> void:
	Game.stop_music()
	var sfx_idx := AudioServer.get_bus_index("SFX")
	var tween := create_tween()
	tween.tween_method(func(db): AudioServer.set_bus_volume_db(sfx_idx, db), AudioServer.get_bus_volume_db(sfx_idx), 0.0, 1.0)
