extends Camera2D
@export var start_zoom := Vector2(2.5, 2.5)
@export var target_zoom := Vector2(1.0, 1.0)
@export var zoom_speed := 2.0

# How fast the camera follows the player (higher = snappier)
@export var follow_smooth := 6.0

# Lookahead: camera moves a bit ahead of the player's horizontal movement
@export var lookahead_distance := 100.0

# Simple bob when walking
@export var bob_amount := 6.0
@export var bob_speed := 10.0
@export var bob_threshold := 10.0

# Small rotation tilt (degrees)
@export var max_tilt_deg := 5.0

# Screen shake default
@export var default_shake_strength := 8.0

var _time := 0.0

# Shake state
var _shake_time := 0.0
var _shake_duration := 0.0
var _shake_strength := 0.0

func _ready():
	zoom = start_zoom

func start_shake(strength: float = 0.0, duration: float = 0.25) -> void:
	# Trigger a simple screen shake
	_shake_strength = strength
	_shake_duration = duration
	_shake_time = duration

func _process(delta):
	_time += delta

	# Smooth zoom toward target
	zoom = zoom.lerp(target_zoom, zoom_speed * delta)

	var parent = get_parent()
	if parent == null:
		return

	# Read parent's horizontal velocity when available
	var vx = 0.0
	if "velocity" in parent:
		vx = parent.velocity.x

	# Horizontal lookahead
	var look_x = clamp(vx / 300.0, -1.0, 1.0) * lookahead_distance

	# Simple vertical bob when walking
	var bob_y = 0.0
	if "is_on_floor" in parent and parent.is_on_floor() and abs(vx) > bob_threshold:
		bob_y = sin(_time * bob_speed) * bob_amount

	# Shake offset
	var shake_offset = Vector2.ZERO
	if _shake_time > 0.0 and _shake_duration > 0.0:
		_shake_time = max(_shake_time - delta, 0.0)
		var t = _shake_time / _shake_duration
		var strength = _shake_strength * t
		shake_offset = Vector2(randf() * 2.0 - 1.0, randf() * 2.0 - 1.0) * strength

	# Build target position (parent + lookahead + bob + shake)
	var target = parent.global_position + Vector2(look_x, bob_y) + shake_offset

	# Smoothly move the camera
	global_position = global_position.lerp(target, follow_smooth * delta)

	# Gentle tilt based on horizontal speed
	var target_tilt = clamp(vx / 300.0, -1.0, 1.0) * deg_to_rad(max_tilt_deg)
	rotation = lerp_angle(rotation, target_tilt, 6.0 * delta)
