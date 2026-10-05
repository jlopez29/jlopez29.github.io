class_name CasinoTuning
extends RefCounted

const STARTING_CASH := 2500.0 # Normal is the primary balance target.
const DIFFICULTIES := {
	"normal": {"name": "Normal", "cash": STARTING_CASH, "restricted": true, "expanded": false},
	"easy": {"name": "Easy / Sandbox-lite", "cash": 30000.0, "restricted": false, "expanded": true},
}
# Approved fixed payout distributions, not a player-controlled RTP slider.
# All awards are total returns including stake. Metrics are derived from the math.
const SLOT_REEL := [0,0,0,0,0,0,1,1,1,1,1,2,2,2,2,3,3,3,4,4]
const SLOT_PROFILES := {
	"starter": {
		"name": "Used Classic Reel", "short_name": "Used Reel", "cost": 750,
		"minimum": 5.0, "maximum": 5.0, "denominations": [2.0, 5.0],
		"reel": SLOT_REEL, "pays": [7,10,16,22,30], "cherry_return": 1,
		"volatility": "Low", "development": 1.0, "development_cap": 3.0,
		"round_minutes": 2, "overhead": 1.0, "repair_chance": 0.10,
		"repair_grace": 4320, "repair_cost": 120.0, "appeal": 1.0, "prestige": 1,
		"unlock_rating": 0.0, "unlock_handle": 0.0, "reserve": 650.0,
		"color": "685344", "screen": "reels",
	},
	"standard": {
		"name": "Standard Reel", "short_name": "Reel", "cost": 1400,
		"minimum": 5.0, "maximum": 10.0, "denominations": [2.0, 5.0, 10.0],
		"reel": SLOT_REEL, "pays": [7,11,16,23,35], "cherry_return": 1,
		"volatility": "Low", "development": 2.0, "development_cap": 6.0,
		"round_minutes": 1, "overhead": 1.5, "repair_chance": 0.07,
		"repair_grace": 5760, "repair_cost": 150.0, "appeal": 1.15, "prestige": 2,
		"unlock_rating": 6.0, "unlock_handle": 500.0, "reserve": 900.0,
		"color": "3c6275", "screen": "reels",
	},
	"video": {
		"name": "Video Slot", "short_name": "Video", "cost": 3200,
		"minimum": 5.0, "maximum": 20.0, "denominations": [5.0, 10.0, 20.0],
		"reel": SLOT_REEL, "pays": [5,10,18,32,65], "cherry_return": 1,
		"volatility": "Medium", "development": 4.0, "development_cap": 12.0,
		"round_minutes": 1, "overhead": 2.5, "repair_chance": 0.05,
		"repair_grace": 7200, "repair_cost": 240.0, "appeal": 1.4, "prestige": 4,
		"unlock_rating": 12.0, "unlock_handle": 3000.0, "reserve": 2200.0,
		"color": "365c85", "screen": "video",
	},
	"premium": {
		"name": "Premium Video Slot", "short_name": "Premium", "cost": 7500,
		"minimum": 10.0, "maximum": 50.0, "denominations": [10.0, 25.0, 50.0],
		"reel": SLOT_REEL, "pays": [3,8,18,45,120], "cherry_return": 1,
		"volatility": "High", "development": 6.0, "development_cap": 20.0,
		"round_minutes": 1, "overhead": 4.0, "repair_chance": 0.035,
		"repair_grace": 8640, "repair_cost": 400.0, "appeal": 1.7, "prestige": 6,
		"unlock_rating": 24.0, "unlock_handle": 12000.0, "reserve": 6500.0,
		"color": "744780", "screen": "video",
	},
	"high_limit": {
		"name": "High-Limit Slot", "short_name": "High Limit", "cost": 15000,
		"minimum": 25.0, "maximum": 100.0, "denominations": [25.0, 50.0, 100.0],
		"reel": SLOT_REEL, "pays": [3,7,17,45,140], "cherry_return": 1,
		"volatility": "High", "development": 8.0, "development_cap": 30.0,
		"round_minutes": 1, "overhead": 6.0, "repair_chance": 0.025,
		"repair_grace": 10080, "repair_cost": 650.0, "appeal": 2.0, "prestige": 8,
		"unlock_rating": 45.0, "unlock_handle": 35000.0, "reserve": 15000.0,
		"color": "8b7135", "screen": "video",
	},
}
static var _slot_profiles: Dictionary = {}

static func slot_profile(id: String) -> Dictionary:
	if _slot_profiles.has(id): return _slot_profiles[id]
	var profile: Dictionary = SLOT_PROFILES[id].duplicate(true)
	var counts := [0, 0, 0, 0, 0]
	for symbol in profile.reel: counts[int(symbol)] += 1
	var expected := 0.0
	var second_moment := 0.0
	var reel_size := float(profile.reel.size())
	for symbol in range(counts.size()):
		var chance := pow(float(counts[symbol]) / reel_size, 3)
		var award := float(profile.pays[symbol])
		expected += chance * award
		second_moment += chance * award * award
	var cherry := float(counts[0]) / reel_size
	var cherry_chance := 3.0 * cherry * cherry * (1.0 - cherry) + cherry * pow(1.0 - cherry, 2)
	expected += cherry_chance * float(profile.cherry_return)
	second_moment += cherry_chance * pow(float(profile.cherry_return), 2)
	profile.rtp = expected
	profile.house_edge = 1.0 - expected
	profile.return_stddev = sqrt(maxf(0, second_moment - expected * expected))
	profile.jackpot_probability = pow(float(counts[4]) / reel_size, 3)
	profile.top_return = float(profile.pays.max())
	_slot_profiles[id] = profile
	return profile

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
	"roulette": {"minimum": 25.0, "maximum": 100.0, "limits": [10.0, 25.0, 50.0]},
	"craps": {"minimum": 25.0, "maximum": 100.0, "limits": [25.0, 50.0]},
	"holdem": {"minimum": 25.0, "maximum": 100.0, "limits": [10.0, 25.0, 50.0]},
}
const DEVELOPMENT_VALUES := {"blackjack": 4.0, "roulette": 5.0, "craps": 7.0, "holdem": 8.0}
const SLOT_DEVELOPMENT_CAP := 30.0 # A developed slot floor can reach the highest Rating; each profile also has a cap.
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
const TABLE_GAME_ROUND_MINUTES := {"blackjack": 2, "roulette": 2, "holdem": 2} # Game minutes per occupied NPC hand/spin.
const VISITOR_CASH := 1000.0
const MAX_GUESTS := 40
# Hospitality is settled on physical delivery; prices and policy are independent.
const DRINK_PROFILES := {"basic": {"name": "Basic drink", "price": 5.0, "cost": 1.0, "comp_eligible": true}}
const COMP_POLICY := {"recent_wager_minutes": 12, "basic_gambling_comps": true}
const DRINK_THIRST_TRIGGER := 12.0
const THIRST_PER_MINUTE := 0.5
const THIRST_DISCOMFORT := 25.0
const THIRST_SATISFACTION_LOSS := 0.6
const DRINK_SATISFACTION_GAIN := 6.0
const DRINK_PREP_SECONDS := 2.0 # Simulated movement seconds, as with the existing service route.
const ENTITY_WALK_SPEED := 64.0 # World units per simulated second, independent of update size.
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
const TABLE_REPAIR_COST := 120.0
const TABLE_MINIMUM := 25.0
const ROLL_SECONDS := 0.3 # NPC dice cadence in game minutes; pass bets resolve over several rolls.
const NPC_ROLL_FATIGUE := 0.002 # Up to 0.17 extra game minutes at minimum crew energy.
const VISITOR_ROLL_FATIGUE := 0.04 # Preserve the existing manually played rail cadence.
const SAVE_VERSION := 10 # One current schema; pre-alpha saves are disposable.
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

# Qualitative guest behavior, separate from game odds and arrival volume.
const GUEST_ARCHETYPES := {
	"casual": {"name": "Casual visitor", "games": ["slots", "roulette", "blackjack"], "preference_bonus": 25.0, "quality": 1.0, "patience": Vector2i(25, 40), "wait_for_slots": false, "watch_chance": 0.35, "hot_interest": 8.0, "bankroll_scale": 0.9, "service_expectation": 1.0},
	"regular": {"name": "Regular", "games": ["slots", "blackjack", "roulette", "craps", "holdem"], "preference_bonus": 45.0, "quality": 2.0, "patience": Vector2i(35, 55), "wait_for_slots": true, "watch_chance": 0.35, "hot_interest": 10.0, "bankroll_scale": 1.0, "service_expectation": 1.0},
	"slots": {"name": "Slot enthusiast", "games": ["slots"], "preference_bonus": 75.0, "quality": 5.0, "patience": Vector2i(45, 65), "wait_for_slots": true, "watch_chance": 0.15, "hot_interest": 3.0, "bankroll_scale": 1.05, "service_expectation": 1.0},
	"dice": {"name": "Dice player", "games": ["craps"], "preference_bonus": 90.0, "quality": 1.0, "patience": Vector2i(40, 60), "wait_for_slots": false, "watch_chance": 0.7, "hot_interest": 25.0, "bankroll_scale": 1.1, "service_expectation": 1.0},
	"tables": {"name": "Table player", "games": ["blackjack", "roulette", "holdem"], "preference_bonus": 75.0, "quality": 0.0, "patience": Vector2i(35, 55), "wait_for_slots": false, "watch_chance": 0.5, "hot_interest": 15.0, "bankroll_scale": 1.1, "service_expectation": 1.1},
	"vip": {"name": "VIP", "games": ["slots", "blackjack", "holdem"], "preference_bonus": 60.0, "quality": 10.0, "patience": Vector2i(25, 40), "wait_for_slots": false, "watch_chance": 0.3, "hot_interest": 12.0, "bankroll_scale": 1.0, "service_expectation": 1.4},
}
const STARTER_ARCHETYPE_WEIGHTS := {"casual": 40, "regular": 25, "slots": 30, "dice": 3, "tables": 2}
const DEVELOPED_ARCHETYPE_WEIGHTS := {"casual": 30, "regular": 20, "slots": 25, "dice": 12, "tables": 13}
const HOT_ACTIVITY_MINUTES := 12
const HOT_WAGER_COUNT := 8
const HOT_PLAYER_COUNT := 2
const THOUGHT_GAME_COOLDOWN := 6
const THOUGHT_SECONDS := 3.5
const THOUGHT_GUEST_SECONDS := 12.0
const THOUGHT_REPEAT_SECONDS := 35.0
const THOUGHT_GLOBAL_SECONDS := 1.5
const THOUGHT_HISTORY_LIMIT := 128

# Individual visits: activity sessions are decision opportunities, not forced exits.
const GUEST_VISITS := {
	"casual": {"session": Vector2i(20, 40), "explore": 0.65, "departure": 1.2},
	"regular": {"session": Vector2i(35, 65), "explore": 0.25, "departure": 0.65},
	"slots": {"session": Vector2i(40, 75), "explore": 0.2, "departure": 0.8},
	"dice": {"session": Vector2i(30, 60), "explore": 0.35, "departure": 0.8},
	"tables": {"session": Vector2i(25, 50), "explore": 0.5, "departure": 0.9},
	"vip": {"session": Vector2i(40, 80), "explore": 0.3, "departure": 0.6},
}
const GUEST_EXPLORE_MINUTES := Vector2i(3, 8)
const GUEST_DRINK_BREAK_MINUTES := Vector2i(8, 16)
const GUEST_DECISION_GAP := Vector2i(2, 5)
const GUEST_APPEAL_WEIGHT := 20.0 # Appeal adds interest; it cannot multiply game preference.
const GUEST_DEPARTURE_BASE := 0.06
const GUEST_ACTIVITY_DEPARTURE := 0.035
const GUEST_VISIT_FATIGUE_START := 120.0
const GUEST_VISIT_FATIGUE_SPAN := 600.0
