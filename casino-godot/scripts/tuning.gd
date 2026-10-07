class_name CasinoTuning
extends RefCounted

const STARTING_CASH := 2500.0 # Normal is the primary balance target.
const DIFFICULTIES := {
	"normal": {"name": "Normal", "cash": STARTING_CASH, "restricted": true, "floor_chunks": {"left": 0, "right": 0, "bottom": 0}},
	"easy": {"name": "Easy / Sandbox-lite", "cash": 30000.0, "restricted": false, "floor_chunks": {"left": 0, "right": 1, "bottom": 0}},
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
	{"id": "blackjack", "name": "Blackjack", "rating": 14.0},
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
# Advisory liquidity planning only; never consulted by settlement or unlock rules.
const RESERVE_OPERATING_HOURS := 4.0
const RESERVE_ADDITIONAL_ASSET_WEIGHT := 0.25
const RESERVE_ADDITIONAL_SEAT_WEIGHT := 0.15
const RESERVE_THIN_FRACTION := 0.25
const RESERVE_ALERT_MINUTES := 60
const TABLE_RESERVE_PROFILES := {
	"blackjack": {"base": 650.0, "return_multiple": 3.0},
	"roulette": {"base": 1200.0, "return_multiple": 36.0},
	"craps": {"base": 2500.0, "return_multiple": 35.0},
	"holdem": {"base": 3000.0, "return_multiple": 100.0},
}
const BLACKJACK_REQUIREMENTS := {"rating": 14.0, "development": 4.0, "capacity": 3, "handle": 12000.0, "guests": 40, "cash": 2450.0}
const BLACKJACK_RESERVE := 650.0 # Suggested after table + onboarding; includes payroll and payouts.
const GUEST_BUDGETS := [
	{"rating": 0.0, "bankroll": Vector2i(40, 140), "wager": 5.0},
	{"rating": 16.0, "bankroll": Vector2i(100, 300), "wager": 10.0},
	{"rating": 28.0, "bankroll": Vector2i(250, 700), "wager": 25.0},
	{"rating": 55.0, "bankroll": Vector2i(400, 1500), "wager": 50.0},
]
# Unlocks introduce a minority of higher-budget arrivals before the next Rating band.
# Existing visits retain their real bankroll and wager cap.
const GUEST_UNLOCK_BUDGETS := [
	{"slot_profile": "standard", "share": 0.25, "bankroll": Vector2i(80, 200), "wager": 10.0},
]
const REVEAL_DISTANCE := 6.0
const STAR_THRESHOLDS := [0.0, 16.0, 28.0, 75.0, 100.0]
const STAR_NAMES := ["Local Joint", "Neighborhood Casino", "Casino", "Destination Casino", "Major Casino"]
const OPENING_REVENUE := 100.0 # Guest wagers, not guaranteed profit.
# World geometry: grow edges without translating the original property/assets.
const STARTER_PROPERTY := Rect2(0, 0, 535, 610)
const FLOOR_CHUNK_WIDTH := 320.0
const FLOOR_CHUNK_HEIGHT := 240.0
const FLOOR_MAX_DIRECTION_CHUNKS := 32
const FLOOR_MAX_NAV_CELLS := 131072
const FLOOR_NAV_CELL := 10.0
const EXPANSION_REFERENCE_AREA := 195200.0 # One initial side column.
const EXPANSION_PURCHASE_GROWTH := 0.20
const EXPANSION_AREA_GROWTH := 0.35
const EXPANSION_PRICE_STEP := 50.0
const PROPERTY_UPKEEP_PER_10000 := 0.35 # Per game hour, even while closed.
const FLOOR_SLOT_INSETS := Vector4(22, 100, 22, 30)
const FLOOR_TABLE_INSETS := Vector4(65, 100, 30, 110)
const FLOOR_WALK_INSETS := Vector4(22, 78, 22, 25)
const ENTRANCE_CLEARANCE := Rect2(215, 82, 105, 50)
const ASSET_AISLE_CLEARANCE := 22.0
const TABLE_GAME_ROUND_MINUTES := {"blackjack": 2, "roulette": 2, "holdem": 2} # Game minutes per occupied NPC hand/spin.
const MAX_GUESTS := 80
const MAX_ASSETS := 128 # Runtime placement and current-save bounds must agree.
const MAX_STAFF := 64
const DEBUG_SNAPSHOT_SECONDS := 0.5
const DEBUG_FULL_SNAPSHOT_SECONDS := 2.0
const FLOOR_PRESENTATION_SECONDS := 5
# Hospitality is settled on physical delivery; prices and policy are independent.
const BAR_COUNTER := Rect2(350, 18, 150, 39)
const BAR_PICKUP_OFFSET := Vector2(80, 72) # Reachable aisle point below the counter.
const BAR_GUEST_OFFSETS := [Vector2(20, 72), Vector2(50, 72), Vector2(80, 72), Vector2(110, 72), Vector2(140, 72)]
const BAR_WAIT_CHANCE := 0.4
const BAR_BREAK_CHANCE := 0.3
const BAR_ANTICIPATION_CHANCE := 0.2
const BAR_SOCIAL_MINUTES := Vector2i(4, 8)
# Product access is independent of the active menu. Margins exclude actual labor.
const DRINK_PROFILES := {
	"basic": {"name": "House Soda", "price": 5.0, "price_min": 3.0, "price_max": 7.0, "cost": 1.0, "demand": 1.4, "prestige": 0, "prep_minutes": 2.0, "comp_eligible": true, "rating": 20.0, "served": 0, "vip": false, "preferences": {"casual": 1.4, "regular": 1.0, "slots": 1.3, "dice": 1.0, "tables": 0.8, "vip": 0.4}},
	"water": {"name": "Sparkling Water", "price": 3.0, "price_min": 2.0, "price_max": 5.0, "cost": 0.6, "demand": 1.1, "prestige": 0, "prep_minutes": 1.0, "comp_eligible": true, "rating": 20.0, "served": 0, "vip": false, "preferences": {"casual": 1.0, "regular": 0.8, "slots": 0.9, "dice": 0.6, "tables": 1.2, "vip": 0.9}},
	"coffee": {"name": "Floor Coffee", "price": 4.0, "price_min": 3.0, "price_max": 6.0, "cost": 1.0, "demand": 0.9, "prestige": 0, "prep_minutes": 3.0, "comp_eligible": true, "rating": 20.0, "served": 0, "vip": false, "preferences": {"casual": 0.8, "regular": 1.5, "slots": 1.4, "dice": 0.9, "tables": 1.0, "vip": 0.5}},
	"lager": {"name": "House Lager", "price": 7.0, "price_min": 5.0, "price_max": 10.0, "cost": 2.0, "demand": 0.9, "prestige": 1, "prep_minutes": 2.0, "comp_eligible": false, "rating": 24.0, "served": 20, "vip": false, "preferences": {"casual": 1.0, "regular": 1.3, "slots": 0.8, "dice": 1.6, "tables": 1.0, "vip": 0.7}},
	"cocktail": {"name": "Neon Highball", "price": 10.0, "price_min": 8.0, "price_max": 14.0, "cost": 3.0, "demand": 0.7, "prestige": 2, "prep_minutes": 4.0, "comp_eligible": false, "rating": 32.0, "served": 60, "vip": false, "preferences": {"casual": 1.2, "regular": 0.7, "slots": 0.5, "dice": 1.0, "tables": 1.4, "vip": 1.2}},
	"premium": {"name": "House Old Fashioned", "price": 16.0, "price_min": 13.0, "price_max": 21.0, "cost": 5.0, "demand": 0.45, "prestige": 4, "prep_minutes": 5.0, "comp_eligible": false, "rating": 45.0, "served": 150, "vip": false, "preferences": {"casual": 0.4, "regular": 0.6, "slots": 0.3, "dice": 0.8, "tables": 1.3, "vip": 1.8}},
	"reserve": {"name": "Reserve Nightcap", "price": 26.0, "price_min": 22.0, "price_max": 34.0, "cost": 9.0, "demand": 0.25, "prestige": 6, "prep_minutes": 6.0, "comp_eligible": false, "rating": 65.0, "served": 300, "vip": true, "preferences": {"casual": 0.15, "regular": 0.3, "slots": 0.2, "dice": 0.5, "tables": 0.8, "vip": 2.2}},
}
const DRINK_PRICE_STEP := 1.0
const DRINK_PRICE_ELASTICITY := 1.5
const DRINK_ORDER_RETRY_MINUTES := 12
const DRINK_PRESTIGE_SATISFACTION := 0.5
const DRINK_PRESTIGE_TASTES := {"casual": 0.03, "regular": 0.04, "slots": 0.01, "dice": 0.04, "tables": 0.07, "vip": 0.12}
const COMP_POLICY := {"recent_wager_minutes": 12, "basic_gambling_comps": true}
const DRINK_THIRST_TRIGGER := 12.0
const THIRST_PER_MINUTE := 0.5
const THIRST_DISCOMFORT := 25.0
const THIRST_SATISFACTION_LOSS := 0.6
const DRINK_SATISFACTION_GAIN := 6.0
const ENTITY_WALK_SPEED := 64.0 # World units per simulated second, independent of update size.
# Traffic scales with real positions. These are arrival opportunities, not targets.
const ARRIVAL_MINUTES := Vector2i(18, 32)
const QUIET_ARRIVAL_MINUTES := Vector2i(28, 48)
const TRAFFIC_RULES := {
	"normal": {"overflow": 0.25, "peak_overflow": 0.35, "pressure": 1.0, "patience": 1.0, "rep_loss": 1.0},
	"easy": {"overflow": 0.20, "peak_overflow": 0.25, "pressure": 0.85, "patience": 1.5, "rep_loss": 0.35},
}
const TRAFFIC_MAX_ACCELERATION := 4.0
const TRAFFIC_FULL_ARRIVAL_CHANCE := 0.45
const TRAFFIC_GROUP_CHANCE := 0.30
const TRAFFIC_WAIT_GRACE_FRACTION := 0.75
const TRAFFIC_WAIT_LIMIT_FRACTION := 1.5
const TRAFFIC_WAIT_SATISFACTION_LOSS := 0.15
const TRAFFIC_BAD_VISITS_PER_REVIEW := 3
const TRAFFIC_REPUTATION_COOLDOWN := 120
const TRAFFIC_REPUTATION_LOSS := 0.3

const OBSERVE_MINUTES := Vector2i(12, 24)
const OBSERVERS_PER_TABLE := 3
const TABLE_CAPACITY := 8
const CREW_REQUIRED := 2 # Abstract crew for this prototype, not a full real-world crew.
const DEALER_WAGE := 20.0 # Per game hour; compressed prototype economy.
const SERVICE_WAGE := 16.0
const STAFF_FATIGUE_PER_MINUTE := 0.20
const STAFF_BREAK_ENERGY := 30.0
const STAFF_EXHAUSTED_ENERGY := 15.0
const STAFF_RETURN_ENERGY := 85.0
const STAFF_BREAK_MINUTES := 45
const STAFF_BREAK_RECOVERY := 1.0
const STAFF_IDLE_RECOVERY := 0.02
const STAFF_RELIEF_RECOVERY := 0.04
const STAFF_SHIFT_MINUTES := 480
const STAFF_OFF_DUTY_MINUTES := 360
const STAFF_OFF_DUTY_RECOVERY := 0.20
const STAFF_SHIFT_HANDOVER_MINUTES := 90
const STAFF_SHIFT_HANDOVER_GAP := 20
const STAFF_RELIEF_RECOMMENDATION := 0.25
const STAFF_NOTICE_COOLDOWN := 60
const STAFF_ROTATION_NOTICE_MINUTES := 3
const TABLE_OVERHEAD := 12.0
const TABLE_REPAIR_COST := 120.0
const ROLL_SECONDS := 0.3 # NPC dice cadence in game minutes; pass bets resolve over several rolls.
const NPC_ROLL_FATIGUE := 0.002 # Up to 0.17 extra game minutes at minimum crew energy.
const VISITOR_ROLL_FATIGUE := 0.04 # Preserve the existing manually played rail cadence.
const SAVE_VERSION := 16 # One current schema; pre-alpha saves are disposable.
const SAVE_PATH := "user://pit-boss.json"
const VISITOR_ROLL_SECONDS := 15.0
const REPAIR_GRACE_MINUTES := 4320 # Three days of operation before any wear check.
const REPAIR_CHECK_MINUTES := 1440 # Check once per operating day.
const REPAIR_CHANCE := 0.08 # Game balance, not a real-world failure estimate.
const FLOOR_SIZE := Vector2(850, 610)
const ENTRY := Vector2(267, 90)
const TABLE_SIZE := Vector2(190, 100)
const CRAPS_SIZE := Vector2(230, 130)
const NAMES := ["Alex", "Morgan", "Sam", "Jordan", "Riley", "Casey", "Taylor", "Drew", "Jesse", "Avery", "Blake", "Kai"]

# Real accomplishments only. Notification timing is presentation time, not a gate.
const MILESTONE_PROFIT := 100.0
const MILESTONE_PROFIT_HANDLE := 1000.0
const MILESTONE_LARGE_RESULT := 500.0
const MILESTONE_MAJOR_RESULT := 1000.0
const MILESTONE_QUEUE_LIMIT := 6
const MILESTONE_SECONDS := 4.0
const MILESTONE_MAJOR_SECONDS := 6.0
const MILESTONE_GAP_SECONDS := 1.0
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

# Owner account and optional happenings (game minutes, not wall-clock timers).
const OWNER_STARTING_BANKROLL := 1000.0
const OWNER_MAX_REWARD := 1000.0
const OWNER_MONEY_LIMIT := 1.0e12
const OWNER_HISTORY_LIMIT := 64
const OWNER_PENDING_LIMIT := 32
const EVENT_INTERVAL_MINUTES := 300
const EVENT_SPAWN_CHANCE := 0.35
const EVENT_QUEUE_LIMIT := 4
const EVENT_VISIBLE_CAP := 1
const EVENT_HISTORY_LIMIT := 32
const EVENT_DRINK_QUEUE_THRESHOLD := 3
const EVENT_SLOT_CROWD_THRESHOLD := 2
const EVENT_GUEST_BIG_WIN := 250.0
const OWNER_EVENT_EXPOSURE_MULTIPLIER := 8.5

# Casino Momentum: game-minute rates, bounded attraction only; never changes odds.
const MOMENTUM_BASELINE := 35.0
const MOMENTUM_BANDS := [{"ceiling": 25.0, "name": "Quiet"}, {"ceiling": 50.0, "name": "Busy"}, {"ceiling": 70.0, "name": "Hot"}, {"ceiling": 85.0, "name": "Packed"}, {"ceiling": 101.0, "name": "Electric"}]
const MOMENTUM_RESPONSE := 0.00288 # Approximately four game hours to halve target distance.
const MOMENTUM_MAX_STEP := 0.06 # At most 3.6 points per game hour.
const MOMENTUM_INFLUENCE_RETENTION := 0.99904 # Approximately 12 game hours half-life.
const MOMENTUM_INFLUENCE_GAIN_CAP := 30.0
const MOMENTUM_INFLUENCE_LOSS_CAP := 15.0
const MOMENTUM_SATISFACTION_WEIGHT := 0.6
const MOMENTUM_SATISFACTION_GAIN_CAP := 15.0
const MOMENTUM_SATISFACTION_LOSS_CAP := 25.0
const MOMENTUM_OCCUPANCY_GAIN := 10.0
const MOMENTUM_COVERAGE_LOSS := 15.0
const MOMENTUM_MAX_ARRIVAL_BONUS := 0.10
const MOMENTUM_OWNER_WIN_GAIN := 8.0
const MOMENTUM_REPAIR_GAIN := 6.0
const MOMENTUM_COMP_GAIN := 3.0
const MOMENTUM_COMPLAINT_LOSS := 3.0
const MOMENTUM_GUEST_WIN_GAIN := 2.0
const MOMENTUM_WIN_COOLDOWN := 180

# Optional objectives: game-minute windows and scarce personal funds, no cash mint.
const OBJECTIVE_ACTIVE_LIMIT := 2
const OBJECTIVE_INTERVAL := 180
const OBJECTIVE_OFFER_MINUTES := 360
const OBJECTIVE_DURATION := 360
const OBJECTIVE_CLAIM_MINUTES := 720
const OBJECTIVE_KIND_COOLDOWN := 720
const OBJECTIVE_HISTORY_LIMIT := 24
const OBJECTIVE_RECENT_WINDOW := 360
const OBJECTIVE_SAMPLE_MINUTES := 30
const OBJECTIVE_SAMPLE_LIMIT := 13
const OBJECTIVE_RECENT_WAGER := 5
const OBJECTIVE_COUNT_FRACTION := 0.5
const OBJECTIVE_COUNT_MAX := 12.0
const OBJECTIVE_HAPPY_SATISFACTION := 70.0
const OBJECTIVE_PROFIT_MIN_HANDLE := 100.0
const OBJECTIVE_PROFIT_FRACTION := 0.5
const OBJECTIVE_PROFIT_MIN := 20.0
const OBJECTIVE_PROFIT_MAX := 500.0
const OBJECTIVE_HOLD_MINUTES := 45.0
const OBJECTIVE_OCCUPIED_MAX := 3
const OBJECTIVE_MOMENTUM_MAX := 65.0
const OBJECTIVE_REWARD_BASE := 35.0
const OBJECTIVE_REWARD_PER_STAR := 10.0
const OBJECTIVE_REWARD_MAX := 85.0
const OBJECTIVE_DAILY_REWARD := 300.0
const OBJECTIVE_BANKROLL_CAP := 2000.0 # Includes pending event stakes.
const OBJECTIVE_MOMENTUM_REWARD := 2.0
