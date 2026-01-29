extends Node

var canvas_layer: CanvasLayer
var toast_resource = preload("res://scenes/toast.tscn")
var toasts = []
var toast_queue = []  
var max_toasts = 5

const MARGIN_TOP = 20
const MARGIN_BETWEEN = 5
const FADE_DURATION = 0.8
const TOAST_LIFETIME = 2.5

func _ready() -> void:
	canvas_layer = CanvasLayer.new()
	canvas_layer.set_name("ToastLayer")
	canvas_layer.layer = 128
	add_child(canvas_layer)

@rpc("call_local")
func add(text: String):
	var config = { "text": text }

	if toasts.size() < max_toasts:
		_show_toast(config)
	else:
		toast_queue.append(config)
		var excess_count = toast_queue.size()
		var counter_toast = _get_counter_toast()

		if excess_count > 0:
			if counter_toast:
				counter_toast.update_text("%d more..." % excess_count)
			else:
				_replace_last_toast_with_counter(excess_count)

		_reposition_toasts()

func _show_toast(config):
	var toast = toast_resource.instantiate()
	canvas_layer.add_child(toast)
	toasts.insert(0, toast)
	toast.init(config)

	await get_tree().process_frame  
	_reposition_toasts()
	if toast != null:
		toast.connect("toast_faded", Callable(self, "_on_toast_removed").bind(toast))

func _replace_last_toast_with_counter(excess_count):
	var last_toast = toasts.pop_back()
	last_toast.queue_free()

	var counter_toast = toast_resource.instantiate()
	canvas_layer.add_child(counter_toast)
	toasts.append(counter_toast)
	counter_toast.init({ "text": "%d more..." % excess_count })
	counter_toast.set_meta("is_counter", true)

	counter_toast.disconnect("toast_faded", Callable(self, "_on_toast_removed"))

	_reposition_toasts() 

func _reposition_toasts():
	var current_y = MARGIN_TOP
	for toast in toasts:
		toast.move_to(current_y)
		current_y += toast.size.y + MARGIN_BETWEEN  

func _on_toast_removed(toast):
	if toast.has_meta("is_counter"):
		return

	toasts.erase(toast)
	_reposition_toasts()

	if toast_queue.size() > 0:
		var next_toast_config = toast_queue.pop_front()
		_show_toast(next_toast_config)

	# Update the counter toast only if there are still queued toasts
	var counter_toast = _get_counter_toast()
	if counter_toast:
		if toast_queue.size() > 0:
			counter_toast.update_text("%d more..." % toast_queue.size())
		else:
			toasts.erase(counter_toast)
			counter_toast.queue_free()

	_reposition_toasts()

func _get_counter_toast():
	for toast in toasts:
		if toast.has_meta("is_counter"):
			return toast
	return null
