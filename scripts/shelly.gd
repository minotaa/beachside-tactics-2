extends CharacterBody2D

# --- CONFIG ---
var dialogue_lines: Array[String] = [
	"Welcome! Take a look around.",
]
var chars_per_second: float = 30.0
var line_display_duration: float = 1.0

# --- STATE ---
var blink_timer: float = 15.0
var is_in_dialogue: bool = false
var current_line_index: int = 0

signal dialogue_finished

var speech_bubble_scene = preload("res://scenes/ui/speech_bubble.tscn")

func _ready() -> void:
	$AnimatedSprite2D.play("idle")

func _process(delta: float) -> void:
	if not is_in_dialogue:
		blink_timer -= delta
		if blink_timer < 0.0:
			blink_timer = 15.0
			$AnimatedSprite2D.play("blink")
			await get_tree().create_timer(1.0).timeout
			$AnimatedSprite2D.play("idle")

func start_dialogue() -> void:
	if is_in_dialogue:
		return
	is_in_dialogue = true
	current_line_index = 0
	play_line(current_line_index)

func play_line(index: int) -> void:
	var bubble: Label = speech_bubble_scene.instantiate()
	add_child(bubble)

	var panel_h: float = bubble.get_node("Panel").size.y
	bubble.global_position = Vector2(
		$Marker2D.position.x - (bubble.get_node("Panel").size.x * 0.0399),
		$Marker2D.position.y - (panel_h * 0.8) * pow(1.35, index)
	)

	var full_text: String = dialogue_lines[index]
	bubble.text = ""

	for i in range(full_text.length()):
		if not is_in_dialogue:
			bubble.queue_free()
			return
		bubble.text = full_text.substr(0, i + 1)
		await get_tree().create_timer(1.0 / chars_per_second).timeout

	await get_tree().create_timer(line_display_duration).timeout

	bubble.queue_free()

	if not is_in_dialogue:
		return

	current_line_index += 1
	if current_line_index < dialogue_lines.size():
		play_line(current_line_index)
	else:
		end_dialogue()

func end_dialogue() -> void:
	is_in_dialogue = false
	dialogue_finished.emit()
