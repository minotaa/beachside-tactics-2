extends Control

signal toast_faded

var is_counter := false

func _ready():
	position = Vector2(get_viewport_rect().size.x - $Label.get_rect().size.x - 10, 0)
	await get_tree().process_frame

	if not is_counter:
		await get_tree().create_timer(Toast.TOAST_LIFETIME).timeout
		fade_out()

func update_text(text: String) -> void:
	$Label.text = text
	await get_tree().process_frame  
	size.y = $Label.get_combined_minimum_size().y + Toast.MARGIN_BETWEEN

func init(config: Dictionary) -> void:
	update_text(config.text)

	if config.text.ends_with("more..."):
		is_counter = true

func move_to(target_y: float) -> void:
	await get_tree().process_frame  
	var tween = get_tree().create_tween()
	tween.tween_property(self, "position", Vector2(get_viewport_rect().size.x - $Label.get_rect().size.x - 10, target_y), 0.3) \
		.set_trans(Tween.TRANS_QUINT) \
		.set_ease(Tween.EASE_OUT)

func fade_out():
	if is_counter:
		await get_tree().create_timer(Toast.TOAST_LIFETIME * 1.5).timeout
		# Let counter toasts fade out after a longer duration

	var tween = get_tree().create_tween()
	tween.tween_property(self, "modulate:a", 0, Toast.FADE_DURATION).set_trans(Tween.TRANS_LINEAR)
	await tween.finished
	emit_signal("toast_faded")
	queue_free()
