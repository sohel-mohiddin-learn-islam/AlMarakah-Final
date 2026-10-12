extends Control

signal movement_changed(direction: Vector2)

var active_touch := -1
var joystick_center := Vector2.ZERO
var joystick_knob := Vector2.ZERO
var movement := Vector2.ZERO
var joystick_radius := 66.0
var enabled_controls := false

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    queue_redraw()

func _draw() -> void:
    if not enabled_controls:
        return

    var center := Vector2(108.0, size.y - 125.0)

    draw_circle(center, joystick_radius + 10.0, Color(0.02, 0.03, 0.04, 0.32))
    draw_circle(center, joystick_radius, Color(0.82, 0.76, 0.62, 0.24))
    draw_arc(center, joystick_radius, 0.0, TAU, 48, Color(0.95, 0.85, 0.64, 0.8), 2.0)

    var knob := center
    if active_touch >= 0:
        knob = joystick_knob

    draw_circle(knob, 27.0, Color(0.91, 0.78, 0.53, 0.85))
    draw_arc(knob, 27.0, 0.0, TAU, 32, Color(1.0, 0.94, 0.78, 0.95), 2.0)

func _gui_input(event: InputEvent) -> void:
    if not enabled_controls:
        return

    if event is InputEventScreenTouch:
        var center := Vector2(108.0, size.y - 125.0)

        if event.pressed:
            if active_touch < 0 and event.position.distance_to(center) < joystick_radius + 45.0:
                active_touch = event.index
                _update_joystick(event.position)
                accept_event()
        elif event.index == active_touch:
            active_touch = -1
            movement = Vector2.ZERO
            movement_changed.emit(movement)
            queue_redraw()
            accept_event()

    elif event is InputEventScreenDrag and event.index == active_touch:
        _update_joystick(event.position)
        accept_event()

func _update_joystick(position: Vector2) -> void:
    var center := Vector2(108.0, size.y - 125.0)
    var offset := position - center

    if offset.length() > joystick_radius:
        offset = offset.normalized() * joystick_radius

    joystick_knob = center + offset
    movement = Vector2(offset.x / joystick_radius, -offset.y / joystick_radius)

    if movement.length() < 0.12:
        movement = Vector2.ZERO
    elif movement.length() > 1.0:
        movement = movement.normalized()

    movement_changed.emit(movement)
    queue_redraw()

func set_controls_enabled(value: bool) -> void:
    enabled_controls = value
    active_touch = -1
    movement = Vector2.ZERO
    movement_changed.emit(movement)
    queue_redraw()
