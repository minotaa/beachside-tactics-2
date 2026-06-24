extends Node

var _pool: Array[AudioStreamPlayer] = []
var _pool_size = 8

func _ready():
	for i in _pool_size:
		var p = AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)

func play(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0):
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return
