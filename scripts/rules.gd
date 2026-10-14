extends RefCounted
## Pure match rules shared by the prototype and its headless regression tests.
##
## The four menu modes intentionally share the same offline simulation. The
## ranked variants provide a local rating loop for design/testing; they are not
## a substitute for an authoritative online service.
const BR_PARTICIPANTS: int = 50
const CS_TEAM_SIZE: int = 4
const CS_ROUNDS_TO_WIN: int = 4
const CS_ROUND_SECONDS: float = 90.0
const ZONE_WAIT: float = 25.0
const ZONE_SHRINK_SECONDS: float = 240.0
const MODE_IDS: Array[String] = ["br_classic", "br_ranked", "cs_classic", "cs_ranked"]
const WeaponCatalog = preload("res://scripts/weapon_catalog.gd")

static func weapon_ids() -> Array[String]:
	return WeaponCatalog.weapon_ids()

static func weapon_labels() -> Dictionary:
	return WeaponCatalog.weapon_labels()

static func is_valid_weapon_id(weapon_id: String) -> bool:
	return WeaponCatalog.weapon_ids().has(weapon_id)

static func base_mode(mode: String) -> String:
	return "cs" if mode.begins_with("cs") else "br"

static func is_ranked(mode: String) -> bool:
	return mode.ends_with("_ranked")

static func participant_count(mode: String) -> int:
	return CS_TEAM_SIZE * 2 if base_mode(mode) == "cs" else BR_PARTICIPANTS

static func mode_label(mode: String) -> String:
	var prefix: String = "CS" if base_mode(mode) == "cs" else "BR"
	var suffix: String = "RANKED PRACTICE" if is_ranked(mode) else "CLASSIC"
	return "%s %s • OFFLINE" % [prefix, suffix]

static func rating_delta(mode: String, won: bool) -> int:
	if not is_ranked(mode):
		return 0
	return (30 if base_mode(mode) == "cs" else 25) if won else (-20 if base_mode(mode) == "cs" else -15)

static func weapon_profile(weapon_id: String) -> Dictionary:
	return WeaponCatalog.weapon_profile(weapon_id)

static func radius_at(elapsed: float, initial_radius: float) -> float:
	var progress: float = clampf((elapsed - ZONE_WAIT) / ZONE_SHRINK_SECONDS, 0.0, 1.0)
	return lerpf(initial_radius, 3.0, progress)

static func zone_damage_at(elapsed: float) -> float:
	return 5.0 + floorf(maxf(elapsed, 0.0) / 60.0) * 3.0

static func enemies(is_cs: bool, team_a: int, team_b: int) -> bool:
	return not is_cs or team_a != team_b

static func cs_winner(living: Array[int], health: Array[float], timed_out: bool) -> int:
	# -2 = still playing; -1 = draw; 0/1 = winning team.
	if living[0] == 0 and living[1] == 0:
		return -1
	if living[0] == 0:
		return 1
	if living[1] == 0:
		return 0
	if not timed_out:
		return -2
	if living[0] != living[1]:
		return 0 if living[0] > living[1] else 1
	if not is_equal_approx(health[0], health[1]):
		return 0 if health[0] > health[1] else 1
	return -1
