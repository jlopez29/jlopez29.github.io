extends RefCounted
## Fixed-size, deterministic presentation pool. Never consumes gambling RNG.
const LIMIT := 48
var positions := PackedVector2Array()
var velocities := PackedVector2Array()
var ages := PackedFloat32Array()
var lifetimes := PackedFloat32Array()
var shapes := PackedInt32Array()
var count := 0

func _init() -> void:
	positions.resize(LIMIT)
	velocities.resize(LIMIT)
	ages.resize(LIMIT)
	lifetimes.resize(LIMIT)
	shapes.resize(LIMIT)

func clear() -> void:
	count = 0

func burst(wins: Array, level: int) -> void:
	count = 6 if level == 2 else 16 if level == 3 else 30 if level == 4 else LIMIT
	for i in range(count):
		var line: Dictionary = wins[i % wins.size()]
		var col := i % 3
		positions[i] = Vector2(0.1+(col+0.5)*0.8/3,0.23+(int(line.path[col])+0.5)*0.48/3)
		var angle := -PI + fmod(i*2.399,PI)
		velocities[i] = Vector2(cos(angle)*0.18,sin(angle)*0.24-0.04)
		if level >= 5 and i % 2 == 0:
			positions[i] = Vector2(0.08+fmod(i*0.618,0.84),0.16)
			velocities[i] = Vector2(sin(i)*0.09,0.15)
		ages[i] = 0
		lifetimes[i] = 0.55+fmod(i*0.173,0.55)
		shapes[i] = 2 if level >= 5 and i % 2 == 0 else 1 if level >= 4 else 0

func advance(delta: float) -> void:
	for i in range(count):
		ages[i] += delta
		if ages[i] >= lifetimes[i]: continue
		positions[i] += velocities[i]*delta
		velocities[i].y += 0.24*delta
