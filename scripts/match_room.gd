extends Node

## Owns the identity and locked player roster for one isolated match room.

var session_id: int = 0
var mode_id: String = ""
var map_id: int = 0
var human_peer_ids: Array = []
var bot_count: int = 0
var state: String = "created"

func setup(room_session_id: int, selected_mode: String, selected_map: int, locked_human_peer_ids: Array, total_players: int) -> void:
    session_id = room_session_id
    mode_id = selected_mode
    map_id = selected_map
    human_peer_ids = locked_human_peer_ids.duplicate()
    bot_count = maxi(total_players - human_peer_ids.size(), 0)
    state = "locked"

func is_active() -> bool:
    return state == "locked" or state == "running"
