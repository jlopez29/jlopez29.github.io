class_name CasinoTuning
extends RefCounted

const STARTING_CASH := 24000.0
const VISITOR_CASH := 1000.0
const MAX_GUESTS := 40
const ARRIVAL_MINUTES := Vector2i(18, 32) # Small parties, with quiet gaps at 1x.
const QUIET_ARRIVAL_MINUTES := Vector2i(28, 48)
const OBSERVE_MINUTES := Vector2i(12, 24)
const OBSERVERS_PER_TABLE := 3
const TABLE_CAPACITY := 8
const CREW_REQUIRED := 2 # Abstract crew for this prototype, not a full real-world crew.
const CRAPS_COST := 3500.0
const DEALER_WAGE := 20.0 # Per game hour; compressed prototype economy.
const SERVICE_WAGE := 16.0
const TABLE_OVERHEAD := 12.0
const TABLE_MINIMUM := 25.0
const ROLL_SECONDS := 6.0
const SAVE_VERSION := 2
const VISITOR_ROLL_SECONDS := 15.0
const REPAIR_GRACE_MINUTES := 4320 # Three days of operation before any wear check.
const REPAIR_CHECK_MINUTES := 1440 # Check once per operating day.
const REPAIR_CHANCE := 0.08 # Game balance, not a real-world failure estimate.
const FLOOR_SIZE := Vector2(850, 610)
const ENTRY := Vector2(425, 565)
const TABLE_SIZE := Vector2(190, 100)
const NAMES := ["Alex", "Morgan", "Sam", "Jordan", "Riley", "Casey", "Taylor", "Drew", "Jesse", "Avery", "Blake", "Kai"]
