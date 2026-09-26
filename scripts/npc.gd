extends CharacterBody2D
class_name NPC

enum Action {
	OPEN_SHOP,
	OPEN_BESTIARY,
	NOTHING
}

# --- CONFIG ---
var action: Action = Action.NOTHING
var npc_name: String = ""
var chars_per_second: float = 30.0
var line_display_duration: float = 1.5

# Dialogue trees: each key is a tree ID, value is an array of dialogue entries.
# Entry format:
# {
#     "text": String or Array (random pick),
#     "next": String or null,         # tree ID to jump to after this line, null = end
#     "choices": [                    # optional, replaces auto-advance
#         {
#             "label": String,
#             "next": String or null,       # default target
#             "condition": String,              # optional, condition name
#             "next_true": String or null,  # optional, used if check passes
#             "next_false": String or null, # optional, used if check fails
#             "quest_trigger": String # optional, fires when the CHOICE is picked
#         }
#     ],
#     "quest_trigger": String,        # optional, fires when this line plays
#     "condition": String,            # optional, tree only available if this condition passes, this doesn't stop the entry from playing if the entry has no "else" AND is played from a previous dialogue entry that meets the criteria
#     "else": String                  # optional, fallback tree ID if condition fails
# }

var dialogue_trees: Dictionary = {}
var default_trees: Array[String] = ["default"]

# -- SHOPKEEPER --
var selling = []

# --- STATE ---
var blink_timer: float = 15.0
var is_in_dialogue: bool = false
var current_tree: String = ""
var current_entry_index: int = 0
var is_immersive: bool = false
var pending_action: bool = false

signal interaction_started
signal interaction_ended
signal dialogue_finished
signal quest_triggered(quest_id: String)
signal choice_made(choice: Dictionary)

var speech_bubble_scene = preload("res://scenes/ui/speech_bubble.tscn")
var choice_bubble_scene = preload("res://scenes/ui/choice_bubble.tscn")
var marker: Vector2

func sells(item: ItemType) -> bool:
	return selling.has(item)

func _ready() -> void:
	$AnimatedSprite2D.play("idle")
	marker = $Marker.global_position

func _process(delta: float) -> void:
	if not is_in_dialogue:
		blink_timer -= delta
		if blink_timer < 0.0:
			blink_timer = randi_range(5, 15.0)
			$AnimatedSprite2D.play("blink")
			await get_tree().create_timer(1.0).timeout
			$AnimatedSprite2D.play("idle")

func start_dialogue(tree_id: String = "") -> void:
	if is_in_dialogue:
		return
	if tree_id == "":
		tree_id = _pick_available_tree()
	if tree_id == "" or not dialogue_trees.has(tree_id):
		return

	is_in_dialogue = true
	pending_action = false

	current_tree = tree_id
	current_entry_index = 0
	_play_entry(dialogue_trees[current_tree][current_entry_index])

func _pick_available_tree() -> String:
	for key in default_trees:
		var resolved := _resolve_tree(key)
		if resolved != "":
			return resolved
	return ""

func _resolve_tree(key: String, depth: int = 0) -> String:
	if depth > 8 or not dialogue_trees.has(key):
		return ""
	var entry = dialogue_trees[key][0]
	if entry.has("condition") and not _check_condition(entry):
		if entry.has("else"):
			return _resolve_tree(entry["else"], depth + 1)
		return ""
	return key

func _play_entry(entry: Dictionary) -> void:
	var entry_immersive: bool = entry.get("immersive", is_immersive)
	if entry_immersive and not is_immersive:
		is_immersive = true
		interaction_started.emit()
	elif not entry_immersive and is_immersive:
		is_immersive = false
		interaction_ended.emit()
		
	if entry.get("trigger_action", false):
		pending_action = true
		
	if entry.has("quest_trigger") and entry["quest_trigger"] != "":
		quest_triggered.emit(entry["quest_trigger"])
		_on_quest_triggered(entry["quest_trigger"])

	var text = entry["text"]
	if text is Array:
		text = text.pick_random()

	if entry.has("choices") and entry["choices"].size() > 0:
		await _show_choices(text, entry["choices"])
	else:
		var bubble = speech_bubble_scene.instantiate()
		add_child(bubble)
		await bubble.play_line(text, marker, chars_per_second, is_immersive, 1.5, true)
		if not is_in_dialogue:
			return
		_advance(entry.get("next", null))

func _resolve_next(chosen: Dictionary) -> Variant:
	if chosen.has("condition"):
		if _evaluate_condition(chosen["condition"]):
			return chosen.get("next_true", chosen.get("next"))
		else:
			return chosen.get("next_false", chosen.get("next"))
	return chosen.get("next", null)

func _show_choices(text: String, choices: Array) -> void:
	var choice_bubble = choice_bubble_scene.instantiate()
	add_child(choice_bubble)
	var chosen = await choice_bubble.show_choices(text, choices, marker, chars_per_second)
	choice_bubble.queue_free()
 
	choice_made.emit(chosen)
 
	if chosen.get("trigger_action", false):
		pending_action = true

	if chosen.has("quest_trigger") and chosen["quest_trigger"] != "":
		quest_triggered.emit(chosen["quest_trigger"])
		_on_quest_triggered(chosen["quest_trigger"])
 
	_advance(_resolve_next(chosen))

func _advance(next) -> void:
	if not is_in_dialogue:
		return

	if next == null:
		end_dialogue()
		return

	if dialogue_trees.has(next):
		current_tree = next
		current_entry_index = 0
		_play_entry(dialogue_trees[current_tree][0])
		return

	current_entry_index += 1
	var tree = dialogue_trees[current_tree]
	if current_entry_index < tree.size():
		_play_entry(tree[current_entry_index])
	else:
		end_dialogue()

func end_dialogue() -> void:
	is_in_dialogue = false
	if is_immersive:
		await get_tree().create_timer(0.1).timeout
		interaction_ended.emit()
		is_immersive = false
	dialogue_finished.emit()

func _check_condition(entry: Dictionary) -> bool:
	if not entry.has("condition") or entry["condition"] == "":
		return true
	return _evaluate_condition(entry["condition"])

func _evaluate_condition(condition: String) -> bool:
	return true

func _on_quest_triggered(quest_id: String) -> void:
	pass
