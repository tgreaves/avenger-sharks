extends Camera2D

# Shared camera for 1 or 2 players.
#
# Follows the midpoint of all living players and zooms to fit their bounding box
# (plus a margin), capped at a maximum zoom-out for readability. In 1-player the
# single player is the midpoint and the box is a point, so it rests at the
# default zoom — behaving like the old player-mounted camera.
#
# `main` supplies the player list (get_players) and living-state. Screen shake is
# owned here so it is shared across both players.

var main
var shake_amount := 0.0
var _base_offset := Vector2.ZERO

# When true, follow/zoom logic is suspended (e.g. during the wave-1 intro tween
# that drives zoom directly, matching the old behaviour).
var manual_control := false


func _ready():
	main = get_parent()
	# Start inactive so the Intro / menu scenes keep their own cameras. Gameplay
	# calls activate() when a wave begins.
	enabled = false


func activate():
	enabled = true
	make_current()


func deactivate():
	enabled = false


func _process(delta):
	if not enabled:
		return

	if not manual_control:
		_follow_players(delta)

	_apply_shake()


func _follow_players(delta):
	var players = _living_players()

	if players.is_empty():
		return

	# Target position = midpoint of living players.
	var midpoint = Vector2.ZERO
	for p in players:
		midpoint += p.global_position
	midpoint /= players.size()

	# Target zoom = fit the players' bounding box plus a margin, capped.
	var target_zoom = _fit_zoom(players)

	var pos_weight = clamp(constants.CAMERA_POSITION_LERP * delta, 0.0, 1.0)
	var zoom_weight = clamp(constants.CAMERA_ZOOM_LERP * delta, 0.0, 1.0)

	global_position = global_position.lerp(midpoint, pos_weight)
	zoom = zoom.lerp(Vector2(target_zoom, target_zoom), zoom_weight)


func _fit_zoom(players) -> float:
	if players.size() < 2:
		return constants.CAMERA_DEFAULT_ZOOM

	# Bounding box of the players.
	var min_p = players[0].global_position
	var max_p = players[0].global_position
	for p in players:
		min_p = min_p.min(p.global_position)
		max_p = max_p.max(p.global_position)

	var span = (max_p - min_p) + Vector2.ONE * (constants.CAMERA_PLAYER_MARGIN * 2.0)
	var viewport = get_viewport_rect().size

	# Zoom that fits both axes (smaller zoom = more zoomed out).
	var zoom_x = viewport.x / span.x
	var zoom_y = viewport.y / span.y
	var fit = min(zoom_x, zoom_y)

	# Never zoom in past default, never zoom out past the cap.
	return clamp(fit, constants.CAMERA_MIN_ZOOM, constants.CAMERA_DEFAULT_ZOOM)


func _living_players() -> Array:
	var living := []
	for p in main.get_players():
		if p.visible and p.is_player_alive():
			living.append(p)
	# Fall back to all players if none report "alive" (e.g. between states), so
	# the camera never freezes on nothing.
	if living.is_empty():
		return main.get_players()
	return living


# --- Screen shake (shared) ---


func shake(amount: float):
	shake_amount = amount


func shake_reset():
	shake_amount = 0.0


func _apply_shake():
	if shake_amount > 0.0:
		offset = _base_offset + Vector2(
			randf_range(-1.0, 1.0) * shake_amount, randf_range(-1.0, 1.0) * shake_amount
		)
	else:
		offset = _base_offset
