extends RefCounted
## Central weapon catalogue for AlMarakah.
## Profiles are shared by loadout selection, combat, HUD and future loot.

const GROUPS: Array = [
    {
        "category": "Assault Rifle",
        "damage": 26.0, "magazine": 30, "reserve": 180,
        "interval": 0.14, "reload": 1.7, "speed": 7.2,
        "range": 200.0, "recoil": 0.10, "pellets": 1,
        "spread": 0.008, "mode": "automatic",
        "weapons": [
            ["rifle", "Rifle"], ["akm", "AKM"],
            ["m4a1", "M4A1"], ["scar_h", "SCAR-H"],
            ["fal", "FAL"], ["aug", "AUG"],
            ["g36", "G36"], ["famas", "FAMAS"],
            ["galil", "Galil"], ["an94", "AN-94"],
            ["groza", "Groza"], ["k2", "K2"]
        ]
    },
    {
        "category": "Submachine Gun",
        "damage": 18.0, "magazine": 36, "reserve": 216,
        "interval": 0.085, "reload": 1.55, "speed": 7.6,
        "range": 115.0, "recoil": 0.075, "pellets": 1,
        "spread": 0.018, "mode": "automatic",
        "weapons": [
            ["smg", "SMG"], ["mp5", "MP5"],
            ["vector", "Vector"], ["ump45", "UMP45"],
            ["p90", "P90"], ["bizon", "PP-19 Bizon"],
            ["mp7", "MP7"], ["mac10", "MAC-10"],
            ["pp19", "PP-19"], ["sten", "Sten"]
        ]
    },
    {
        "category": "Shotgun",
        "damage": 9.0, "magazine": 8, "reserve": 64,
        "interval": 0.8, "reload": 2.5, "speed": 6.9,
        "range": 38.0, "recoil": 0.20, "pellets": 8,
        "spread": 0.075, "mode": "pump",
        "weapons": [
            ["m870", "M870"], ["saiga12", "Saiga-12"],
            ["spas12", "SPAS-12"], ["origin12", "Origin-12"],
            ["ksg", "KSG"], ["db12", "DB-12"],
            ["striker", "Striker"], ["m1014", "M1014"]
        ]
    },
    {
        "category": "Sniper Rifle",
        "damage": 92.0, "magazine": 5, "reserve": 40,
        "interval": 1.25, "reload": 2.8, "speed": 6.1,
        "range": 300.0, "recoil": 0.28, "pellets": 1,
        "spread": 0.002, "mode": "bolt",
        "weapons": [
            ["awm", "AWM"], ["m24", "M24"],
            ["kar98", "Kar98"], ["mosin", "Mosin-Nagant"],
            ["ax50", "AX-50"], ["intervention", "Intervention"],
            ["sv98", "SV-98"], ["scout", "Scout"]
        ]
    },
    {
        "category": "Marksman Rifle",
        "damage": 48.0, "magazine": 12, "reserve": 96,
        "interval": 0.48, "reload": 2.0, "speed": 6.5,
        "range": 240.0, "recoil": 0.16, "pellets": 1,
        "spread": 0.004, "mode": "semi",
        "weapons": [
            ["marksman", "Marksman"], ["sks", "SKS"],
            ["slr", "SLR"], ["mini14", "Mini-14"],
            ["mk14", "Mk 14"], ["vss", "VSS"]
        ]
    },
    {
        "category": "Light Machine Gun",
        "damage": 25.0, "magazine": 60, "reserve": 240,
        "interval": 0.12, "reload": 3.8, "speed": 6.2,
        "range": 190.0, "recoil": 0.17, "pellets": 1,
        "spread": 0.025, "mode": "automatic",
        "weapons": [
            ["m249", "M249"], ["dp28", "DP-28"],
            ["mg3", "MG3"], ["rpk", "RPK"],
            ["m60", "M60"], ["pkm", "PKM"]
        ]
    },
    {
        "category": "Pistol",
        "damage": 24.0, "magazine": 15, "reserve": 90,
        "interval": 0.22, "reload": 1.45, "speed": 7.4,
        "range": 75.0, "recoil": 0.09, "pellets": 1,
        "spread": 0.018, "mode": "semi",
        "weapons": [
            ["pistol", "Pistol"], ["deagle", "Desert Eagle"],
            ["glock18", "Glock 18"], ["m1911", "M1911"],
            ["p92", "P92"], ["revolver", "Revolver"],
            ["usp", "USP"], ["p226", "P226"],
            ["five_seven", "Five-seveN"], ["dual_pistols", "Dual Pistols"]
        ]
    }
]


static func weapon_ids() -> Array[String]:
    var result: Array[String] = []
    for group in GROUPS:
        for weapon in group["weapons"]:
            result.append(String(weapon[0]))
    return result


static func weapon_labels() -> Dictionary:
    var result: Dictionary = {}
    for group in GROUPS:
        for weapon in group["weapons"]:
            result[String(weapon[0])] = String(weapon[1])
    return result


static func weapon_profile(weapon_id: String) -> Dictionary:
    for group in GROUPS:
        var weapons: Array = group["weapons"]
        for index in weapons.size():
            var weapon: Array = weapons[index]
            if String(weapon[0]) != weapon_id:
                continue

            var variation: float = float(index % 4)
            var profile: Dictionary = {
                "id": String(weapon[0]),
                "name": String(weapon[1]),
                "category": String(group["category"]),
                "damage": float(group["damage"]) * (1.0 + variation * 0.025),
                "magazine_size": int(group["magazine"]),
                "reserve": int(group["reserve"]),
                "fire_interval": float(group["interval"]) * (1.0 + variation * 0.035),
                "reload_seconds": float(group["reload"]) * (1.0 + float(index % 3) * 0.04),
                "move_speed": float(group["speed"]),
                "range": float(group["range"]),
                "recoil": float(group["recoil"]) * (1.0 + variation * 0.04),
                "pellets": int(group["pellets"]),
                "spread": float(group["spread"]),
                "fire_mode": String(group["mode"])
            }

            # Preserve the original three loadouts' established gameplay values.
            if weapon_id == "rifle":
                profile.merge({
                    "damage": 26.0, "magazine_size": 30, "reserve": 180,
                    "fire_interval": 0.14, "reload_seconds": 1.7,
                    "move_speed": 7.2
                }, true)
            elif weapon_id == "smg":
                profile.merge({
                    "damage": 18.0, "magazine_size": 36, "reserve": 216,
                    "fire_interval": 0.085, "reload_seconds": 1.55,
                    "move_speed": 7.6
                }, true)
            elif weapon_id == "marksman":
                profile.merge({
                    "damage": 48.0, "magazine_size": 12, "reserve": 96,
                    "fire_interval": 0.48, "reload_seconds": 2.0,
                    "move_speed": 6.5
                }, true)

            return profile

    return weapon_profile("rifle")
