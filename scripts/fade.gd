extends Node

var canvas_layer: CanvasLayer
var fade_rect: ColorRect
var iris_shader: Shader
var shader_material: ShaderMaterial
var is_fading = false

func _ready():
	canvas_layer = CanvasLayer.new()
	canvas_layer.set_name("IrisFadeLayer")
	canvas_layer.layer = 128
	add_child(canvas_layer)
	
	iris_shader = load("res://scripts/wipe.gdshader")
	shader_material = ShaderMaterial.new()
	shader_material.shader = iris_shader
	
	fade_rect = ColorRect.new()
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.color = Color.WHITE
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.material = shader_material
	canvas_layer.add_child(fade_rect)
	
	# Default shader parameters
	shader_material.set_shader_parameter("progress", 0.0)
	shader_material.set_shader_parameter("fade_color", Vector3(0.0, 0.0, 0.0))
	shader_material.set_shader_parameter("center", Vector2(0.5, 0.5))
	_update_aspect_ratio()

func _update_aspect_ratio():
	var viewport_size = get_viewport().get_visible_rect().size
	var aspect = viewport_size.x / viewport_size.y
	shader_material.set_shader_parameter("aspect_ratio", aspect)

# Iris wipe to a new scene — circle closes, scene changes, circle opens
func fade_to_scene(scene_path: String, fade_duration: float = 1.0):
	if is_fading:
		return
	is_fading = true
	_update_aspect_ratio()
	
	# Close the iris
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(_update_progress, 0.0, 1.0, fade_duration / 2.0)
	await tween.finished
	
	get_tree().change_scene_to_file(scene_path)
	
	# Open the iris
	tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(_update_progress, 1.0, 0.0, fade_duration / 2.0)
	await tween.finished
	is_fading = false

# Circle closes in (iris closes to black)
func fade_out(fade_duration: float = 1.0):
	if is_fading:
		return
	is_fading = true
	_update_aspect_ratio()
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(_update_progress, 0.0, 1.0, fade_duration)
	await tween.finished

# Circle opens out (iris expands to reveal scene)
func fade_in(fade_duration: float = 1.0):
	_update_aspect_ratio()
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(_update_progress, 1.0, 0.0, fade_duration)
	await tween.finished
	is_fading = false

# Move the iris center (e.g. focus on a character before closing)
# x and y are in 0.0–1.0 UV space
func set_iris_center(x: float, y: float):
	shader_material.set_shader_parameter("center", Vector2(x, y))

# Set iris color (default black)
func set_fade_color(color: Color):
	shader_material.set_shader_parameter("fade_color", Vector3(color.r, color.g, color.b))

func _update_progress(value: float):
	shader_material.set_shader_parameter("progress", value)
