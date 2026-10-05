class_name CasinoTuning
extends RefCounted

const STARTING_CASH := 2500.0 # Normal is the primary balance target.
const DIFFICULTIES := {
	"normal": {"name": "Normal", "cash": STARTING_CASH, "restricted": true, "expanded": false},
	"easy": {"name": "Easy / Sandbox-lite", "cash": 30000.0, "restricted": false, "expanded": true},
}
const GAME_COSTS := {"slots": 750, "blackjack": 1800, "roulette": 2500, "craps": 6000, "holdem": 8000}
const HIRING_COST := 150.0
const EXPANSION_COST := 3000.0
const VIP_COST := 2500.0
const HIGH_LIMIT_COST := 3500.0
# Ordered access milestones. Rating is earned through satisfied guest play,
# never through visitor transfers or a guaranteed gaming win.
const MILESTONES := [
	{"id": "slots", "name": "Slot Machine", "rating": 0.0},
	{"id": "blackjack", "name": "Blackjack", "rating": 8.0},
	{"id": "service", "name": "Bar / drink service", "rating": 14.0},
	{"id": "roulette", "name": "Roulette", "rating": 28.0},
	{"id": "expansion", "name": "Floor expansion", "rating": 35.0},
	{"id": "craps", "name": "Craps", "rating": 45.0},
	{"id": "vip", "name": "VIP access", "rating": 55.0},
	{"id": "high_limit", "name": "High-limit capability", "rating": 70.0},
	{"id": "holdem", "name": "Ultimate Texas Hold’em", "rating": 75.0},
]
const RATING_PER_ROUND := 0.08
const RATING_SATISFACTION_MIN := 65.0
const REVEAL_DISTANCE := 6.0
const STAR_THRESHOLDS := [0.0, 8.0, 28.0, 75.0, 100.0]
const STAR_NAMES := ["Local Joint", "Neighborhood Casino", "Casino", "Destination Casino", "Major Casino"]
const OPENING_REVENUE := 100.0 # Guest wagers, not guaranteed profit.
const STARTER_BUILD_AREA := Rect2(65, 100, 440, 400)
const FULL_BUILD_AREA := Rect2(65, 100, 720, 400)
const SLOT_ROUND_MINUTES := 2
const TABLE_GAME_ROUND_MINUTES := 6 # Non-craps guest games; supports staffed progression.
const SLOT_OVERHEAD := 1.0 # Per hour; slots must support a small starting business.
const VISITOR_CASH := 1000.0
const MAX_GUESTS := 40
const ARRIVAL_MINUTES := Vector2i(18, 32) # Small parties, with quiet gaps at 1x.
const QUIET_ARRIVAL_MINUTES := Vector2i(28, 48)
const OBSERVE_MINUTES := Vector2i(12, 24)
const OBSERVERS_PER_TABLE := 3
const TABLE_CAPACITY := 8
const CREW_REQUIRED := 2 # Abstract crew for this prototype, not a full real-world crew.
const CRAPS_COST := 6000.0
const DEALER_WAGE := 20.0 # Per game hour; compressed prototype economy.
const SERVICE_WAGE := 16.0
const TABLE_OVERHEAD := 12.0
const TABLE_MINIMUM := 25.0
const ROLL_SECONDS := 6.0
const SAVE_VERSION := 4 # One current schema; pre-alpha saves are disposable.
const SAVE_PATH := "user://neon-house.json"
const VISITOR_ROLL_SECONDS := 15.0
const REPAIR_GRACE_MINUTES := 4320 # Three days of operation before any wear check.
const REPAIR_CHECK_MINUTES := 1440 # Check once per operating day.
const REPAIR_CHANCE := 0.08 # Game balance, not a real-world failure estimate.
const FLOOR_SIZE := Vector2(850, 610)
const ENTRY := Vector2(425, 565)
const TABLE_SIZE := Vector2(190, 100)
const CRAPS_SIZE := Vector2(230, 130)
const NAMES := ["Alex", "Morgan", "Sam", "Jordan", "Riley", "Casey", "Taylor", "Drew", "Jesse", "Avery", "Blake", "Kai"]
