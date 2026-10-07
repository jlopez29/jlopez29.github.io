extends RefCounted
## A timeline over a committed result. Reads outcomes; emits presentation events.
signal cue(name: String)
signal state_changed(value: int)
const Result = preload("res://scripts/slot_result.gd")
enum Phase { IDLE, SPINNING, ANTICIPATION, REEL_STOPPING, RESULT, LINE_REVEAL, WIN_COUNT, CELEBRATION, READY }
const STOP_TIMES := [0.78,1.03,1.30]
const SNAP_SECONDS := 0.16
const RECOGNITION_SECONDS := 0.10
const LINE_SECONDS := 0.32
const ALL_LINES_SECONDS := 0.35
var phase := Phase.IDLE
var elapsed := 0.0
var ends := STOP_TIMES.duplicate()
var reveal_at := 1.56
var count_at := 1.74
var finish_at := 1.92
var active := false
var anticipation := false
var stopped := 0
var revealed := false
var counted := false
var wins: Array = []
var info: Dictionary = {}

func reset(result: Dictionary, sponsored: bool) -> void:
	active = false
	elapsed = 0
	stopped = 3
	revealed = not result.is_empty()
	counted = revealed
	wins = result.get("winning_lines", [])
	info = Result.describe(result,sponsored)
	set_phase(Phase.READY if revealed else Phase.IDLE)

func start(result: Dictionary, sponsored: bool) -> void:
	reset(result,sponsored)
	anticipation = false
	for i in range(int(result.active_lines)):
		var path: Array = CasinoTuning.SLOT_LINES[i]
		if result.grid[path[0]][0] == result.grid[path[1]][1]: anticipation = true
	ends = [STOP_TIMES[0],STOP_TIMES[1],STOP_TIMES[2] + (0.22 if anticipation else 0.0)]
	reveal_at = float(ends[2]) + SNAP_SECONDS + (RECOGNITION_SECONDS if not wins.is_empty() else 0.0)
	count_at = reveal_at + (0.18 if not wins.is_empty() else 0.0)
	finish_at = reveal_at + 0.18 if wins.is_empty() else maxf(reveal_at + wins.size()*LINE_SECONDS + ALL_LINES_SECONDS, count_at + float(info.count_seconds) + 0.10)
	active = true
	stopped = 0
	revealed = false
	counted = false
	set_phase(Phase.SPINNING)
	cue.emit("spin")

func advance(delta: float) -> void:
	if not active: return
	elapsed = minf(finish_at,elapsed + delta)
	# Boundary crossings are one-shot events, independent of UI refresh polling.
	while stopped < 3 and elapsed >= float(ends[stopped]):
		stopped += 1
		cue.emit("stop%d" % stopped)
	if not revealed and elapsed >= reveal_at:
		revealed = true
		if int(info.level) == 1: cue.emit("ack")
	if not counted and elapsed >= count_at:
		counted = true
		if info.positive:
			cue.emit("top" if int(info.level) == 6 else "big" if int(info.level) >= 4 else "small")
			cue.emit("burst")
	if elapsed >= finish_at:
		active = false
		set_phase(Phase.READY)
	elif revealed:
		set_phase(Phase.LINE_REVEAL if elapsed < count_at else Phase.WIN_COUNT if count_progress() < 1 else Phase.CELEBRATION)
	elif elapsed >= float(ends[2]) + SNAP_SECONDS:
		set_phase(Phase.RESULT)
	elif anticipation and stopped == 2:
		set_phase(Phase.ANTICIPATION)
	elif stopped > 0 and elapsed - float(ends[stopped-1]) < SNAP_SECONDS:
		set_phase(Phase.REEL_STOPPING)
	else:
		set_phase(Phase.SPINNING)

func set_phase(value: int) -> void:
	if phase == value: return
	phase = value
	state_changed.emit(phase)

func skip() -> bool:
	if not active or not revealed: return false
	elapsed = finish_at
	active = false
	counted = true
	set_phase(Phase.READY)
	return true

func count_progress() -> float:
	if not active: return 1.0 if revealed else 0.0
	if not revealed: return 0.0
	return clampf((elapsed-count_at)/float(info.count_seconds),0,1)

func balance_progress() -> float:
	if not active: return 1.0
	if not revealed: return 0.0
	var span := float(info.count_seconds) if not wins.is_empty() else 0.18
	return clampf((elapsed-reveal_at)/span,0,1)

func line_index() -> int:
	if not active or not revealed or wins.is_empty(): return -1
	var index := floori((elapsed-reveal_at)/LINE_SECONDS)
	return index if index < wins.size() else -1

func all_lines() -> bool:
	var together_at := reveal_at+wins.size()*LINE_SECONDS
	return active and revealed and not wins.is_empty() and elapsed >= together_at and elapsed < together_at+ALL_LINES_SECONDS

func line_progress(index: int) -> float:
	if all_lines(): return 1.0
	if line_index() != index: return 0.0
	return clampf((elapsed-reveal_at-index*LINE_SECONDS)/0.28,0,1)

func symbol_age(row: int, col: int) -> float:
	if not active or not revealed: return -1.0
	var selected := line_index()
	for i in range(wins.size()):
		if not all_lines() and selected != i: continue
		if int(wins[i].path[col]) != row: continue
		var since := elapsed - reveal_at - i*LINE_SECONDS - col*0.14
		if since >= 0: return since
	return -1.0

func strong_result() -> bool:
	return active and revealed and int(info.get("level",0)) >= 4

func cabinet_state() -> String:
	if not active: return "IDLE"
	if not revealed: return "ANTICIPATION" if phase == Phase.ANTICIPATION else "RESULT" if phase == Phase.RESULT else "SPINNING"
	return "TOP_AWARD" if int(info.level) == 6 else "BIG_WIN" if int(info.level) >= 4 else "WIN" if info.positive else "RESULT"
