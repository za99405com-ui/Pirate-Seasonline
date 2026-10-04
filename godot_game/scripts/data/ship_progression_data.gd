class_name ShipProgressionData
extends RefCounted

class LevelInfo:
	var level: int
	var title: String
	var description: String
	var max_health: float
	var max_speed: float
	var turn_speed: float
	var acceleration: float
	var cannon_damage: float
	var reload_time: float
	var storage_capacity: int
	var upgrade_gold_cost: int
	var visible_parts: Array[String]
	var unlocked_slots: Array[String]

	func _init(
		p_level: int,
		p_title: String,
		p_desc: String,
		p_hp: float,
		p_spd: float,
		p_turn: float,
		p_accel: float,
		p_dmg: float,
		p_reload: float,
		p_storage: int,
		p_cost: int,
		p_parts: Array[String],
		p_slots: Array[String]
	) -> void:
		level = p_level
		title = p_title
		description = p_desc
		max_health = p_hp
		max_speed = p_spd
		turn_speed = p_turn
		acceleration = p_accel
		cannon_damage = p_dmg
		reload_time = p_reload
		storage_capacity = p_storage
		upgrade_gold_cost = p_cost
		visible_parts = p_parts
		unlocked_slots = p_slots

static var _levels: Dictionary = {}

static func _initialize_levels() -> void:
	if not _levels.is_empty():
		return

	# LEVEL 1
	_levels[1] = LevelInfo.new(
		1, "Row Skiff", "Small primitive skiff. Single mast and simple canvas.",
		100.0, 13.0, 1.45, 4.0, 30.0, 2.2, 20, 0,
		["hull_base", "mast_main", "sail_main", "cannons_pair_1"],
		["slot_cannon_port_1", "slot_cannon_starboard_1", "slot_sail_main"]
	)

	# LEVEL 2
	_levels[2] = LevelInfo.new(
		2, "Fisher Sloop", "Improved deck planks and a small provision crate.",
		110.0, 13.3, 1.48, 4.1, 32.0, 2.15, 23, 75,
		["hull_base", "mast_main", "sail_main", "cannons_pair_1", "deck_trim", "crate_small"],
		["slot_cannon_port_1", "slot_cannon_starboard_1", "slot_sail_main", "slot_storage_crate"]
	)

	# LEVEL 3
	_levels[3] = LevelInfo.new(
		3, "Coast Raider", "Extended bowsprit, carved stern balcony and a rum barrel for morale.",
		122.0, 13.6, 1.52, 4.25, 34.0, 2.1, 26, 120,
		["hull_base", "mast_main", "sail_main", "cannons_pair_1", "deck_trim", "crate_small", "barrel_small", "bowsprit_spar", "stern_extension"],
		["slot_cannon_port_1", "slot_cannon_starboard_1", "slot_sail_main", "slot_storage_crate", "slot_cosmetic_bow"]
	)

	# LEVEL 4
	_levels[4] = LevelInfo.new(
		4, "Privateer Scout", "Wood gunwale moldings, carved railings, deck rope coils and waving pirate ensign.",
		135.0, 14.0, 1.55, 4.35, 36.0, 2.05, 30, 180,
		["hull_base", "mast_main", "sail_main", "cannons_pair_1", "deck_trim", "crate_small", "barrel_small", "bowsprit_spar", "stern_extension", "side_railings", "stern_flag", "rope_coils"],
		["slot_cannon_port_1", "slot_cannon_starboard_1", "slot_sail_main", "slot_storage_crate", "slot_cosmetic_flag", "slot_cosmetic_bow"]
	)

	# LEVEL 5
	# LEVEL 5
	_levels[5] = LevelInfo.new(
		5, "Corsair Sloop", "Sturdier hull with reinforced captain quarter, carved balcony and cargo tier.",
		150.0, 14.4, 1.60, 4.5, 39.0, 2.0, 35, 250,
		["hull_base", "mast_main", "sail_main", "cannons_pair_1", "deck_trim", "crate_small", "barrel_small", "bowsprit_spar", "stern_extension", "side_railings", "stern_flag", "rope_coils", "captain_cabin", "cargo_stack_a"],
		["slot_cannon_port_1", "slot_cannon_starboard_1", "slot_sail_main", "slot_storage_crate", "slot_storage_hold", "slot_cosmetic_flag"]
	)

	# LEVEL 6
	_levels[6] = LevelInfo.new(
		6, "Swift Brigantine", "Reinforced tall mast, top topsail sail, and a warm night lantern.",
		165.0, 14.8, 1.63, 4.6, 42.0, 1.95, 39, 340,
		["hull_base", "mast_main", "sail_main", "cannons_pair_1", "deck_trim", "crate_small", "barrel_small", "bowsprit_spar", "stern_extension", "side_railings", "stern_flag", "rope_coils", "captain_cabin", "cargo_stack_a", "top_sail", "lantern_front"],
		["slot_cannon_port_1", "slot_cannon_starboard_1", "slot_sail_main", "slot_sail_top", "slot_utility_lantern", "slot_storage_hold"]
	)

	# LEVEL 7
	_levels[7] = LevelInfo.new(
		7, "Smuggler Vanguard", "Expanded beam, double barrel rack, and open deck cargo slots.",
		180.0, 15.2, 1.67, 4.75, 45.0, 1.90, 43, 450,
		["hull_base", "mast_main", "sail_main", "cannons_pair_1", "deck_trim", "crate_small", "barrel_small", "bowsprit_spar", "stern_extension", "side_railings", "stern_flag", "rope_coils", "captain_cabin", "cargo_stack_a", "top_sail", "lantern_front", "barrel_pair", "gear_bench"],
		["slot_cannon_port_1", "slot_cannon_starboard_1", "slot_sail_main", "slot_sail_top", "slot_utility_gear", "slot_utility_lantern", "slot_storage_hold"]
	)

	# LEVEL 8
	_levels[8] = LevelInfo.new(
		8, "Iron Gun Sloop", "Dual heavy broadside cannons per side and reinforced hull gunwales.",
		198.0, 15.6, 1.70, 4.9, 48.0, 1.85, 47, 580,
		["hull_base", "mast_main", "sail_main", "cannons_pair_1", "cannons_pair_2", "deck_trim", "crate_small", "barrel_small", "bowsprit_spar", "stern_extension", "side_railings", "stern_flag", "rope_coils", "captain_cabin", "cargo_stack_a", "top_sail", "lantern_front", "barrel_pair", "gear_bench", "reinforced_gunwales", "extended_wake"],
		["slot_cannon_port_1", "slot_cannon_port_2", "slot_cannon_starboard_1", "slot_cannon_starboard_2", "slot_sail_main", "slot_sail_top", "slot_utility_gear"]
	)

	# LEVEL 9
	_levels[9] = LevelInfo.new(
		9, "Buccaneer Marauder", "Captain's iron-banded chest mounted on deck and aft transom lantern.",
		216.0, 16.0, 1.74, 5.0, 51.0, 1.80, 51, 720,
		["hull_base", "mast_main", "sail_main", "cannons_pair_1", "cannons_pair_2", "deck_trim", "crate_small", "barrel_small", "bowsprit_spar", "stern_extension", "side_railings", "stern_flag", "rope_coils", "captain_cabin", "cargo_stack_a", "top_sail", "lantern_front", "barrel_pair", "gear_bench", "reinforced_gunwales", "extended_wake", "captain_chest", "lantern_stern"],
		["slot_cannon_port_1", "slot_cannon_port_2", "slot_cannon_starboard_1", "slot_cannon_starboard_2", "slot_storage_chest", "slot_utility_lantern", "slot_utility_gear"]
	)

	# LEVEL 10
	_levels[10] = LevelInfo.new(
		10, "Storm Corsair", "Wide quarterdeck, triangular headsail jib, and expanded sea hold.",
		235.0, 16.4, 1.78, 5.15, 54.0, 1.75, 55, 900,
		["hull_base", "mast_main", "sail_main", "cannons_pair_1", "cannons_pair_2", "deck_trim", "crate_small", "barrel_small", "bowsprit_spar", "stern_extension", "side_railings", "stern_flag", "rope_coils", "captain_cabin", "cargo_stack_a", "cargo_stack_b", "top_sail", "jib_sail", "lantern_front", "barrel_pair", "gear_bench", "reinforced_gunwales", "extended_wake", "captain_chest", "lantern_stern", "wide_quarterdeck"],
		["slot_cannon_port_1", "slot_cannon_port_2", "slot_cannon_starboard_1", "slot_cannon_starboard_2", "slot_sail_main", "slot_sail_top", "slot_sail_jib", "slot_storage_chest", "slot_storage_hold"]
	)

	# LEVEL 11
	_levels[11] = LevelInfo.new(
		11, "Sea Wolf Hunter", "Carved gun ports, elegant bulwark banisters, and secure locker.",
		255.0, 16.8, 1.82, 5.3, 57.0, 1.70, 60, 1100,
		["hull_base", "mast_main", "sail_main", "cannons_pair_1", "cannons_pair_2", "deck_trim", "crate_small", "barrel_small", "bowsprit_spar", "stern_extension", "side_railings", "stern_flag", "rope_coils", "captain_cabin", "cargo_stack_a", "cargo_stack_b", "top_sail", "jib_sail", "lantern_front", "barrel_pair", "gear_bench", "reinforced_gunwales", "extended_wake", "captain_chest", "lantern_stern", "wide_quarterdeck", "carved_gunports", "side_bulwarks"],
		["slot_cannon_port_1", "slot_cannon_port_2", "slot_cannon_starboard_1", "slot_cannon_starboard_2", "slot_sail_main", "slot_sail_top", "slot_sail_jib", "slot_storage_chest", "slot_storage_hold", "slot_utility_locker"]
	)

	# LEVEL 12
	_levels[12] = LevelInfo.new(
		12, "Ironclad Raider", "Heavy riveted iron bands across hull and coiled rope rigging bundles.",
		275.0, 17.1, 1.86, 5.4, 60.0, 1.65, 66, 1350,
		["hull_base", "mast_main", "sail_main", "cannons_pair_1", "cannons_pair_2", "deck_trim", "crate_small", "barrel_small", "bowsprit_spar", "stern_extension", "side_railings", "stern_flag", "rope_coils", "captain_cabin", "cargo_stack_a", "cargo_stack_b", "top_sail", "jib_sail", "lantern_front", "barrel_pair", "gear_bench", "reinforced_gunwales", "extended_wake", "captain_chest", "lantern_stern", "wide_quarterdeck", "carved_gunports", "side_bulwarks", "metal_armor_bands", "rigging_coils"],
		["slot_cannon_port_1", "slot_cannon_port_2", "slot_cannon_starboard_1", "slot_cannon_starboard_2", "slot_sail_main", "slot_sail_top", "slot_sail_jib", "slot_storage_chest", "slot_storage_hold", "slot_utility_locker", "slot_utility_rigging"]
	)

	# LEVEL 13
	_levels[13] = LevelInfo.new(
		13, "Gilded Corsair", "Golden dragon/skull figurehead at the bow and ornate stern gallery.",
		295.0, 17.5, 1.90, 5.55, 62.0, 1.60, 71, 1650,
		["hull_base", "mast_main", "sail_main", "cannons_pair_1", "cannons_pair_2", "deck_trim", "crate_small", "barrel_small", "bowsprit_spar", "stern_extension", "side_railings", "stern_flag", "rope_coils", "captain_cabin", "cargo_stack_a", "cargo_stack_b", "top_sail", "jib_sail", "lantern_front", "barrel_pair", "gear_bench", "reinforced_gunwales", "extended_wake", "captain_chest", "lantern_stern", "wide_quarterdeck", "carved_gunports", "side_bulwarks", "metal_armor_bands", "rigging_coils", "bow_figurehead", "ornate_transom"],
		["slot_cannon_port_1", "slot_cannon_port_2", "slot_cannon_starboard_1", "slot_cannon_starboard_2", "slot_sail_main", "slot_sail_top", "slot_sail_jib", "slot_storage_chest", "slot_storage_hold", "slot_utility_locker", "slot_cosmetic_figurehead"]
	)

	# LEVEL 14
	_levels[14] = LevelInfo.new(
		14, "Dread Leviathan", "Forged bow ram armor, heavy iron chest vault, and forward sea anchor.",
		315.0, 17.8, 1.95, 5.7, 64.0, 1.55, 75, 2000,
		["hull_base", "mast_main", "sail_main", "cannons_pair_1", "cannons_pair_2", "deck_trim", "crate_small", "barrel_small", "bowsprit_spar", "stern_extension", "side_railings", "stern_flag", "rope_coils", "captain_cabin", "cargo_stack_a", "cargo_stack_b", "top_sail", "jib_sail", "lantern_front", "barrel_pair", "gear_bench", "reinforced_gunwales", "extended_wake", "captain_chest", "lantern_stern", "wide_quarterdeck", "carved_gunports", "side_bulwarks", "metal_armor_bands", "rigging_coils", "bow_figurehead", "ornate_transom", "bow_anchor", "iron_vault"],
		["slot_cannon_port_1", "slot_cannon_port_2", "slot_cannon_starboard_1", "slot_cannon_starboard_2", "slot_sail_main", "slot_sail_top", "slot_sail_jib", "slot_storage_chest", "slot_storage_hold", "slot_utility_anchor", "slot_cosmetic_figurehead"]
	)

	# LEVEL 15
	_levels[15] = LevelInfo.new(
		15, "Pirate Flagship", "Supreme Master of the Seven Seas. Fully armored, majestic sails and full arsenal.",
		340.0, 18.2, 2.05, 5.85, 68.0, 1.50, 80, 2500,
		["hull_base", "mast_main", "sail_main", "cannons_pair_1", "cannons_pair_2", "deck_trim", "crate_small", "barrel_small", "bowsprit_spar", "stern_extension", "side_railings", "stern_flag", "rope_coils", "captain_cabin", "cargo_stack_a", "cargo_stack_b", "top_sail", "jib_sail", "lantern_front", "barrel_pair", "gear_bench", "reinforced_gunwales", "extended_wake", "captain_chest", "lantern_stern", "wide_quarterdeck", "carved_gunports", "side_bulwarks", "metal_armor_bands", "rigging_coils", "bow_figurehead", "ornate_transom", "bow_anchor", "iron_vault", "skull_crest_sail", "gilded_finishes"],
		["slot_cannon_port_1", "slot_cannon_port_2", "slot_cannon_starboard_1", "slot_cannon_starboard_2", "slot_sail_main", "slot_sail_top", "slot_sail_jib", "slot_storage_chest", "slot_storage_hold", "slot_utility_anchor", "slot_cosmetic_figurehead", "slot_cosmetic_flag"]
	)

static func get_level_info(level: int) -> LevelInfo:
	_initialize_levels()
	var clamped_lvl = clamp(level, 1, 15)
	return _levels[clamped_lvl]
