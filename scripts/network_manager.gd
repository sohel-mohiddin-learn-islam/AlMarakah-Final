extends Node
## Multiplayer session manager.
## Keeps networking isolated from the current offline game flow.

signal connected_to_server
signal connection_failed
signal server_disconnected
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal matchmaking_updated
signal matchmaking_locked(selected_mode: String, selected_map: int, ready_peer_ids: Array, session_id: int)

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 60

var is_host: bool = false
var connected: bool = false
var player_count: int = 0

const MATCHMAKING_SECONDS: float = 10.0

var matchmaking_active: bool = false
var matchmaking_mode: String = ""
var matchmaking_map: int = 0
var matchmaking_ready: Dictionary = {}
var matchmaking_time_left: float = 0.0

var active_match: bool = false
var active_match_mode: String = ""
var active_match_map: int = 0
var active_match_players: Array = []
var next_match_session_id: int = 1
var matchmaking_session_id: int = 0
var active_match_session_id: int = 0
var match_rooms: Dictionary = {}

func _register_match_room(session_id: int, selected_mode: String, selected_map: int, human_peer_ids: Array) -> void:
    var total_players: int = 8 if selected_mode.begins_with("cs") else 50
    var room := {
        "session_id": session_id,
        "mode": selected_mode,
        "map": selected_map,
        "human_peer_ids": human_peer_ids.duplicate(),
        "bot_count": maxi(total_players - human_peer_ids.size(), 0),
        "state": "locked"
    }
    match_rooms[session_id] = room

func get_match_room(session_id: int) -> Dictionary:
    if not match_rooms.has(session_id):
        return {}
    return match_rooms[session_id].duplicate(true)

func host(port: int = DEFAULT_PORT) -> int:
    if multiplayer.multiplayer_peer != null:
        return ERR_ALREADY_IN_USE

    var peer := ENetMultiplayerPeer.new()
    var error := peer.create_server(port, MAX_PLAYERS - 1)

    if error != OK:
        return error

    multiplayer.multiplayer_peer = peer
    is_host = true
    connected = true
    player_count = 1
    return OK

func join(address: String, port: int = DEFAULT_PORT) -> int:
    if multiplayer.multiplayer_peer != null:
        return ERR_ALREADY_IN_USE

    var peer := ENetMultiplayerPeer.new()
    var error := peer.create_client(address, port)

    if error != OK:
        return error

    multiplayer.multiplayer_peer = peer
    is_host = false
    connected = false
    player_count = 0
    return OK

@rpc("any_peer", "reliable")
func request_matchmaking_ready(selected_mode: String, selected_map: int) -> void:
    if not is_host:
        return
    var peer_id: int = multiplayer.get_remote_sender_id()
    if peer_id <= 0:
        peer_id = multiplayer.get_unique_id()
    if not matchmaking_active:
        matchmaking_active = true
        matchmaking_session_id = next_match_session_id
        next_match_session_id += 1
        matchmaking_mode = selected_mode
        matchmaking_map = selected_map
        matchmaking_time_left = MATCHMAKING_SECONDS
    if matchmaking_mode != selected_mode or matchmaking_map != selected_map:
        return
    matchmaking_ready[peer_id] = true
    matchmaking_updated.emit()

func disconnect_session() -> void:
    if multiplayer.multiplayer_peer != null:
        multiplayer.multiplayer_peer.close()

    multiplayer.multiplayer_peer = null
    is_host = false
    connected = false
    player_count = 0

func _process(delta: float) -> void:
    if not is_host or not matchmaking_active:
        return
    matchmaking_time_left -= delta
    if matchmaking_time_left <= 0.0:
        matchmaking_time_left = 0.0
        active_match = true
        active_match_mode = matchmaking_mode
        active_match_map = matchmaking_map
        active_match_players = matchmaking_ready.keys().duplicate()
        active_match_session_id = matchmaking_session_id
        _register_match_room(active_match_session_id, active_match_mode, active_match_map, active_match_players)
        matchmaking_locked.emit(active_match_mode, active_match_map, active_match_players, active_match_session_id)
        matchmaking_ready.clear()
        matchmaking_active = false
        matchmaking_updated.emit()

func _ready() -> void:
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    multiplayer.connected_to_server.connect(_on_connected_to_server)
    multiplayer.connection_failed.connect(_on_connection_failed)
    multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_peer_connected(peer_id: int) -> void:
    player_count = multiplayer.get_peers().size() + (1 if is_host else 0)
    peer_joined.emit(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
    player_count = multiplayer.get_peers().size() + (1 if is_host else 0)
    peer_left.emit(peer_id)

func _on_connected_to_server() -> void:
    connected = true
    player_count = multiplayer.get_peers().size() + 1
    connected_to_server.emit()

func _on_connection_failed() -> void:
    connected = false
    player_count = 0
    connection_failed.emit()

func _on_server_disconnected() -> void:
    connected = false
    is_host = false
    player_count = 0
    server_disconnected.emit()
