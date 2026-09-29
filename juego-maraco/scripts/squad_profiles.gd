extends RefCounted
const Squad = preload("res://scripts/squad_data.gd")

static func mg42_team() -> Squad:
	return Squad.new(true, 3, "MG42 TEAM", "HEAVY SUPPORT / SUPPRESSION", 300, [
		{"id": "gunner", "role": "MG42 GUNNER", "weapon": "MG42"},
		{"id": "assistant", "role": "ASSISTANT GUNNER", "weapon": "Kar98k"},
		{"id": "ammo_bearer", "role": "AMMUNITION BEARER", "weapon": "Kar98k"},
	], {"movement": 2, "attack_range": 5, "base_hit_chance": 80,
		"minimum_damage": 60, "maximum_damage": 80, "grenade_capacity": 0,
		"stationary_accuracy_bonus": 10, "stationary_range_bonus": 1,
		"overwatch_accuracy_penalty": 5, "suppression_on_hit": 2, "suppression_on_miss": 1,
		"ai_role": "support"})

static func machine_gun_team() -> Squad:
	return Squad.new(false, 3, "U.S. MACHINE GUN TEAM", "SUPPORT", 320, [
		{"id": "gunner", "role": "M1919 GUNNER", "weapon": "M1919"},
		{"id": "assistant", "role": "ASSISTANT GUNNER", "weapon": "M1 Carbine"},
		{"id": "ammo_bearer", "role": "AMMUNITION BEARER", "weapon": "M1 Garand"},
	], {"movement": 2, "attack_range": 5, "base_hit_chance": 75,
		"minimum_damage": 55, "maximum_damage": 75, "grenade_capacity": 0,
		"stationary_accuracy_bonus": 10, "stationary_range_bonus": 1,
		"overwatch_accuracy_penalty": 5, "suppression_on_hit": 2, "suppression_on_miss": 1,
		"flank_damage_multiplier": 1.1, "rear_damage_multiplier": 1.2})

static func rifle_squad() -> Squad:
	return Squad.new(false, 5, "U.S. RIFLE SQUAD", "GENERAL-PURPOSE INFANTRY", 450, [
		{"id": "leader", "role": "SQUAD LEADER", "weapon": "M1 Carbine"},
		{"id": "rifleman_1", "role": "RIFLEMAN", "weapon": "M1 Garand"},
		{"id": "rifleman_2", "role": "RIFLEMAN", "weapon": "M1 Garand"},
		{"id": "rifleman_3", "role": "RIFLEMAN", "weapon": "M1 Garand"},
		{"id": "bar_gunner", "role": "BAR GUNNER", "weapon": "BAR"},
	], {"attack_range": 4, "base_hit_chance": 80, "minimum_damage": 70, "maximum_damage": 95})
