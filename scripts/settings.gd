extends RefCounted
## Device-local preferences. Ranked ratings are explicitly local practice data;
## they are not an account, leaderboard, or authenticated competitive rank.
const DEFAULTS = {
	"camera_sensitivity": 1.0,
	"ads_sensitivity": 0.65,
	"aim_assist": true,
	"hud_scale": 1.0,
	"hud_opacity": 0.85,
	"hud_positions": {},
	"weapon_id": "rifle",
	"br_rating": 1000,
	"cs_rating": 1000,
}
var data: Dictionary = DEFAULTS.duplicate(true)
var storage_path: String = "user://almarakah_settings.json"

func load_settings() -> void:
	if not FileAccess.file_exists(storage_path):
		return
	var json = JSON.new()
	if json.parse(FileAccess.get_file_as_string(storage_path)) != OK:
		return
	var parsed = json.data
	if parsed is Dictionary:
		for key in DEFAULTS:
			if parsed.has(key) and typeof(parsed[key]) == typeof(DEFAULTS[key]):
				data[key] = parsed[key]
	_validate()

func _validate() -> void:
	data.camera_sensitivity = clampf(float(data.camera_sensitivity), 0.2, 3.0)
	data.ads_sensitivity = clampf(float(data.ads_sensitivity), 0.2, 3.0)
	data.hud_scale = clampf(float(data.hud_scale), 0.7, 1.5)
	data.hud_opacity = clampf(float(data.hud_opacity), 0.3, 1.0)
	if String(data.weapon_id) not in ["rifle", "smg", "marksman"]:
		data.weapon_id = "rifle"
	data.br_rating = clampi(int(data.br_rating), 0, 5000)
	data.cs_rating = clampi(int(data.cs_rating), 0, 5000)
	var valid: Dictionary = {}
	for key in data.hud_positions:
		var point = data.hud_positions[key]
		if point is Array and point.size() == 2:
			if (point[0] is float or point[0] is int) and (point[1] is float or point[1] is int):
				valid[key] = [clampf(float(point[0]), 0.05, 0.95), clampf(float(point[1]), 0.15, 0.92)]
	data.hud_positions = valid

func save() -> void:
	_validate()
	var file = FileAccess.open(storage_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
	else:
		push_warning("Could not save Almarakah preferences on this device.")

func reset() -> void:
	data = DEFAULTS.duplicate(true)
	save()
