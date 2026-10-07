extends Node
## Original temporary cues; replace these assets without changing game rules.
const CUES := {
	"spin": preload("res://assets/pit_boss/casino_play/slots/audio/spin.wav"),
	"stop1": preload("res://assets/pit_boss/casino_play/slots/audio/stop1.wav"),
	"stop2": preload("res://assets/pit_boss/casino_play/slots/audio/stop2.wav"),
	"stop3": preload("res://assets/pit_boss/casino_play/slots/audio/stop3.wav"),
	"ack": preload("res://assets/pit_boss/casino_play/slots/audio/stop3.wav"),
	"small": preload("res://assets/pit_boss/casino_play/slots/audio/small.wav"),
	"big": preload("res://assets/pit_boss/casino_play/slots/audio/big.wav"),
	"top": preload("res://assets/pit_boss/casino_play/slots/audio/top.wav"),
	"free": preload("res://assets/pit_boss/casino_play/slots/audio/free.wav")
}
var volume := 0.65
var player := AudioStreamPlayer.new()
var last_cue := -1000

func _ready() -> void:
	add_child(player)

func cue(name: String) -> void:
	if volume <= 0 or not CUES.has(name) or Time.get_ticks_msec() - last_cue < 65: return
	last_cue = Time.get_ticks_msec()
	player.stop() # One bounded voice, never a wall of overlapping sounds.
	player.volume_db = linear_to_db(volume) - (17.0 if name == "ack" else 12.0)
	player.stream = CUES[name]
	player.play()

func _exit_tree() -> void:
	player.stop()
	player.stream = null
