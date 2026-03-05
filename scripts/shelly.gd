extends CharacterBody2D

var blink_timer = 15.0

func _ready() -> void:
	$AnimatedSprite2D.play("idle")
	
func _process(delta: float) -> void:
	blink_timer -= delta
	if blink_timer < 0.0:
		blink_timer = 15.0
		$AnimatedSprite2D.play("blink")
		await get_tree().create_timer(1.0).timeout
		$AnimatedSprite2D.play("idle")
