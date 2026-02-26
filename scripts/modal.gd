extends Node

var canvas_layer: CanvasLayer 
var visible_modal
var disabled_controls := []

func _ready() -> void:
	canvas_layer = CanvasLayer.new()
	canvas_layer.set_name("ModalLayer")
	canvas_layer.layer = 128
	canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas_layer)

func add(modal: Control) -> void:
	if visible_modal:
		remove()

	visible_modal = modal
	canvas_layer.add_child(preload("res://scenes/ui/dim.tscn").instantiate())
	canvas_layer.add_child(modal)

	disabled_controls.clear()
	_disable_other_controls(get_tree().current_scene)

func remove() -> void:
	if visible_modal:
		visible_modal.queue_free()
		visible_modal = null

	for children in canvas_layer.get_children():
		children.queue_free()
	_restore_disabled_controls()
	
func _disable_other_controls(node: Node) -> void:
	if node == canvas_layer or node.is_in_group("modal_exempt"):
		return

	for child in node.get_children():
		if child is Control:
			# Store state
			disabled_controls.append({
				"node": child,
				"mouse_filter": child.mouse_filter,
				"disabled": "disabled" in child and child.disabled
			})
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if "disabled" in child:
				child.disabled = true
		_disable_other_controls(child)

func _restore_disabled_controls() -> void:
	for entry in disabled_controls:
		var node = entry["node"]
		if is_instance_valid(node):
			node.mouse_filter = entry["mouse_filter"]
			if "disabled" in node:
				node.disabled = entry["disabled"]
	disabled_controls.clear()
