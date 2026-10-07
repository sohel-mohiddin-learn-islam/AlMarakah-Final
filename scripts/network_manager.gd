extends Node
## Multiplayer session manager.
## Keeps networking isolated from the current offline game flow.

signal connected_to_server
signal connection_failed
signal server_disconnected
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 60

var is_host: bool = false
var connected: bool = false
var player_count: int = 0

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

func disconnect_session() -> void:
    if multiplayer.multiplayer_peer != null:
        multiplayer.multiplayer_peer.close()

    multiplayer.multiplayer_peer = null
    is_host = false
    connected = false
    player_count = 0

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
