extends RefCounted
## Cached at startup by AudioManager. Aliases share physical recordings and buses.
const ROOT := "res://assets/pit_boss/audio/"
const FILES := {
	"music": ["music/casino_jazz.ogg"], "floor": ["ambience/casino_floor.ogg"],
	"deal": ["games/shared/card-slide-1.ogg", "games/shared/card-slide-2.ogg"],
	"flip": ["games/shared/card-place-1.ogg", "games/shared/card-place-2.ogg"],
	"fold": ["games/shared/card-shove-1.ogg"],
	"chip": ["games/shared/chip-lay-1.ogg", "games/shared/chip-lay-2.ogg"],
	"payout": ["games/shared/chips-stack-1.ogg"],
	"pickup": ["games/craps/dice-grab-1.ogg"], "throw": ["games/craps/dice-shake-1.ogg"],
	"bounce": ["games/craps/dice-two-roll-01.wav", "games/craps/dice-two-roll-02.wav"],
	"wall": ["games/craps/wood-bowl-hit-wood-spoon-01.wav"], "settle": ["games/craps/die-throw-1.ogg"],
	"land": ["games/roulette/ball-land.wav"],
	"wheel": ["games/roulette/coin-spin-fall-01.wav"], "ball": ["games/roulette/wood-bowl-drop-nuts-01.wav"],
	"glass": ["world/bar/vials-glass-rattle-01.wav", "world/bar/vials-glass-rattle-02.wav"],
	"door": ["world/doors/keyhole-lockbox-unlock-01.wav"],
	"menu": ["ui/open_001.ogg"], "confirm": ["ui/select_001.ogg"],
	"win": ["ui/confirmation_001.ogg"], "loss": ["ui/back_001.ogg"], "invalid": ["ui/error_001.ogg"]
}
const ALIASES := {"hit": "deal", "stand": "confirm", "double": "chip", "split": "deal", "natural": "win", "push": "confirm", "check": "confirm", "raise": "chip", "point": "confirm", "point_made": "win", "seven_out": "loss", "build": "win", "unlock": "win", "warning": "invalid", "transfer": "payout", "repair": "confirm", "jackpot": "win"}

static func load_streams() -> Dictionary:
	var result := {}
	for cue in FILES:
		var variants: Array[AudioStream] = []
		for path in FILES[cue]:
			if ResourceLoader.exists(ROOT + path):
				var stream := load(ROOT + path) as AudioStream
				if stream != null: variants.append(stream)
		result[cue] = variants
	for cue in ALIASES: result[cue] = result.get(ALIASES[cue], [])
	for cue in ["spin", "stop1", "stop2", "stop3", "ack", "small", "big", "top", "free"]:
		var path: String = "res://assets/pit_boss/casino_play/slots/audio/" + ("stop3" if cue == "ack" else cue) + ".wav"
		result["slot_" + cue] = [load(path)] if ResourceLoader.exists(path) else []
	return result
