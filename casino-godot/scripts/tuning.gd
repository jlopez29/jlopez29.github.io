class_name CasinoTuning
extends RefCounted

const STARTING_CASH := 2500.0 # Normal is the primary balance target.
const DIFFICULTIES := {
	"normal": {"name": "Normal", "cash": STARTING_CASH, "restricted": true, "expanded": false},
	"easy": {"name": "Easy / Sandbox-lite", "cash": 30000.0, "restricted": false, "expanded": true},
}
# One profile today, selected per machine. Future quality can carry more development
# value without changing settlement, guest exposure or unlock logic.
const SLOT_PROFILES := {
	"starter": {
		"cost": 750, "minimum": 5.0, "maximum": 5.0, "denominations": [2.0, 5.0],
		"reel": [0,0,0,0,0,0,1,1,1,1,1,2,2,2,2,3,3,3,4,4],
		"pays": [7,10,16,22,30], "cherry_return": 1,
		"rtp": 0.9135, "house_edge": 0.0865, "volatility": "Low",
		"jackpot_probability": 0.001, "development": 1.0,
		"round_minutes": 2, "overhead": 1.0,
		"repair_chance": 0.08, "repair_grace": 4320, "repair_cost": 120.0, "appeal": 1.0,
	},
}
const GAME_COSTS := {"slots": SLOT_PROFILES.starter.cost, "blackjack": 1800, "roulette": 2500, "craps": 6000, "holdem": 8000}
const HIRING_COST := 150.0
const EXPANSION_COST := 3000.0
const VIP_COST := 2500.0
const HIGH_LIMIT_COST := 3500.0
# Property development and settled guest business earn Rating; perception is reputation.
const MILESTONES := [
	{"id": "slots", "name": "Slot Machine", "rating": 0.0},
	{"id": "blackjack", "name": "Blackjack", "rating": 16.0},
	{"id": "service", "name": "Bar / drink service", "rating": 20.0},
	{"id": "roulette", "name": "Roulette", "rating": 28.0},
	{"id": "expansion", "name": "Floor expansion", "rating": 35.0},
	{"id": "craps", "name": "Craps", "rating": 45.0},
	{"id": "vip", "name": "VIP access", "rating": 55.0},
	{"id": "high_limit", "name": "High-limit capability", "rating": 70.0},
	{"id": "holdem", "name": "Ultimate Texas Hold’em", "rating": 75.0},
]
const GAME_LIMITS := {
	"blackjack": {"minimum": 10.0, "maximum": 100.0, "limits": [10.0, 25.0, 50.0]},
	"roulette": {"minimum": 10.0, "maximum": 100.0, "limits": [10.0, 25.0, 50.0]},
	"craps": {"minimum": 25.0, "maximum": 100.0, "limits": [25.0, 50.0]},
	"holdem": {"minimum": 10.0, "maximum": 100.0, "limits": [10.0, 25.0, 50.0]},
}
const DEVELOPMENT_VALUES := {"blackjack": 4.0, "roulette": 5.0, "craps": 7.0, "holdem": 8.0}
const SLOT_DEVELOPMENT_CAP := 4.0 # Extra cheap machines add earnings, not unlimited Rating.
const RATING_HANDLE_UNIT := 3000.0
const RATING_GUEST_UNIT := 20.0
const BLACKJACK_REQUIREMENTS := {"rating": 16.0, "development": 4.0, "capacity": 3, "handle": 12000.0, "guests": 80, "cash": 2450.0}
const BLACKJACK_RESERVE := 650.0 # Suggested after table + onboarding; includes payroll and payouts.
const GUEST_BUDGETS := [
	{"rating": 0.0, "bankroll": Vector2i(40, 140), "wager": 5.0},
	{"rating": 16.0, "bankroll": Vector2i(100, 300), "wager": 10.0},
	{"rating": 28.0, "bankroll": Vector2i(250, 700), "wager": 25.0},
	{"rating": 55.0, "bankroll": Vector2i(400, 1500), "wager": 50.0},
]
const REVEAL_DISTANCE := 6.0
const STAR_THRESHOLDS := [0.0, 16.0, 28.0, 75.0, 100.0]
const STAR_NAMES := ["Local Joint", "Neighborhood Casino", "Casino", "Destination Casino", "Major Casino"]
const OPENING_REVENUE := 100.0 # Guest wagers, not guaranteed profit.
const STARTER_BUILD_AREA := Rect2(65, 100, 440, 400)
const FULL_BUILD_AREA := Rect2(65, 100, 720, 400)
const TABLE_GAME_ROUND_MINUTES := 6 # Non-craps guest games; supports staffed progression.
const VISITOR_CASH := 1000.0
const MAX_GUESTS := 40
const ARRIVAL_MINUTES := Vector2i(18, 32) # Small parties, with quiet gaps at 1x.
const ARRIVAL_OVERFLOW_RATIO := 0.25 # One extra visitor for two/four slots; scales with seats.
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
const SAVE_VERSION := 5 # One current schema; pre-alpha saves are disposable.
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

# Real-time financial presentation; real seconds, independent of simulation speed.
const MONEY_IMPORTANCE_THRESHOLDS := [10.0, 100.0, 1000.0]
const MONEY_HISTORY_LIMIT := 12
const HOUSE_ACTIVITY_GAMING_THRESHOLD := 500.0 # Absolute settled net house result; routine spins stay on the floor.
const HOUSE_ACTIVITY_LIMIT := 8
const MONEY_POPUP_SECONDS := 1.3
const MONEY_POPUP_IMPORTANCE_SECONDS := 0.2
const MONEY_POPUP_RISE := 36.0
const MONEY_POPUP_OFFSET := 24.0
const MONEY_POPUP_MERGE_SECONDS := 0.12
const MONEY_POPUPS_PER_ASSET := 3
const MONEY_POPUP_LIMIT := 24
const TREASURY_SMOOTHING := 12.0
const TREASURY_FLASH_SECONDS := 0.6

static func money_importance(amount: float) -> int:
	var importance := 0
	for threshold in MONEY_IMPORTANCE_THRESHOLDS:
		if absf(amount) >= float(threshold): importance += 1
	return importance
