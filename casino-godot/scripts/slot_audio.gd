extends Node
## Preserve the timeline adapter; AudioManager owns the single bounded slot voice.
func cue(name: String) -> void:
	AudioManager.play_game("slots", name)

func _exit_tree() -> void:
	AudioManager.stop_game()
