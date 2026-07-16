extends Node2D

var obstacle_dict: Dictionary
var astar: AStarGrid2D

# Obstacles and doors are drawn on the "Items" TileMapLayer at runtime.
@onready var items_layer: TileMapLayer = $Items


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


# Top / Bottom door functions.
func open_top_door():
	# During a boss fight the "exit" is the boss room's own top door, so open that
	# instead of the arena's far top door.
	if _boss_room_active:
		open_boss_top_door()
		return

	items_layer.set_cell(Vector2(31, 2), -1, Vector2i(9, 7))

	items_layer.set_cell(Vector2(32, 2), -1, Vector2i(9, 7))


func close_top_door():
	items_layer.set_cell(Vector2(31, 2), 0, Vector2i(6, 6))

	items_layer.set_cell(Vector2(32, 2), 0, Vector2i(7, 6))


func open_bottom_door():
	items_layer.set_cell(Vector2(31, 33), -1, Vector2i(6, 6))

	items_layer.set_cell(Vector2(32, 33), -1, Vector2i(7, 6))


func close_bottom_door():
	items_layer.set_cell(Vector2(31, 33), 0, Vector2i(6, 6))

	items_layer.set_cell(Vector2(32, 33), 0, Vector2i(7, 6))


# --- Boss arena walls ---
# Wall off a one-screen room for a boss fight (camera locks static on it) so the
# player can't escape the danger. Uses the SAME perimeter + door tiles as the
# arena edge (source 0, Walls layer) and marks cells solid for A*. Doors are the
# usual 2-tile ones (cols 31-32): the bottom door opens for the swim-in and
# closes behind the sharks; the top door opens on defeat for the escape.

const WALL_SOURCE := 0
# Edge / corner atlas tiles, matching the arena perimeter exactly.
const WALL_TOP := Vector2i(1, 0)
const WALL_BOTTOM := Vector2i(1, 4)
const WALL_LEFT := Vector2i(0, 1)
const WALL_RIGHT := Vector2i(5, 1)
const WALL_CORNER_TL := Vector2i(0, 0)
const WALL_CORNER_TR := Vector2i(5, 0)
const WALL_CORNER_BL := Vector2i(0, 4)
const WALL_CORNER_BR := Vector2i(5, 4)
# Closed-door tiles (as used by the arena's own doors), left & right halves.
const DOOR_CLOSED_L := Vector2i(6, 6)
const DOOR_CLOSED_R := Vector2i(7, 6)
# The door occupies these two columns in the top/bottom walls (matches the arena).
const DOOR_COLS := [31, 32]

@onready var walls_layer: TileMapLayer = $Walls

var _boss_box_tiles := {"left": 0, "right": 0, "top": 0, "bottom": 0}
var _boss_wall_cells := []
var _boss_room_active := false


# box is a world-space Rect2 (position = top-left, size). Returns the walled
# interior in world space so callers (camera / boss bounds) stay aligned. The
# bottom door is left OPEN (for the swim-in); the top wall is solid until the
# boss is defeated (open_boss_top_door).
func build_boss_walls(box: Rect2) -> Rect2:
	_boss_wall_cells.clear()
	_boss_room_active = true

	var tl = get_tilemap_coords(box.position)
	var br = get_tilemap_coords(box.position + box.size)
	# Push the side walls out one tile so the interior is a touch wider.
	var left = tl.x - 1
	var right = br.x + 1
	var top = tl.y
	var bottom = br.y
	_boss_box_tiles = {"left": left, "right": right, "top": top, "bottom": bottom}

	# Side walls.
	for y in range(top + 1, bottom):
		_set_boss_wall(Vector2i(left, y), WALL_LEFT)
		_set_boss_wall(Vector2i(right, y), WALL_RIGHT)

	# Top and bottom walls. The top has a CLOSED door (opens on defeat); the
	# bottom leaves its door open for the swim-in (closed behind the sharks).
	for x in range(left + 1, right):
		if DOOR_COLS.has(x):
			# Closed door tile in the top wall — non-solid for A* so the key-holder
			# can path to it (physical collision opens it, like the arena's door).
			var door_tile = DOOR_CLOSED_L if x == DOOR_COLS[0] else DOOR_CLOSED_R
			_set_boss_wall(Vector2i(x, top), door_tile, false)
		else:
			_set_boss_wall(Vector2i(x, top), WALL_TOP)
			_set_boss_wall(Vector2i(x, bottom), WALL_BOTTOM)

	# Corners.
	_set_boss_wall(Vector2i(left, top), WALL_CORNER_TL)
	_set_boss_wall(Vector2i(right, top), WALL_CORNER_TR)
	_set_boss_wall(Vector2i(left, bottom), WALL_CORNER_BL)
	_set_boss_wall(Vector2i(right, bottom), WALL_CORNER_BR)

	var inside_tl = get_position_from_tilemap(Vector2i(left + 1, top + 1))
	var inside_br = get_position_from_tilemap(Vector2i(right, bottom))
	return Rect2(inside_tl, inside_br - inside_tl)


# Close the bottom door behind the sharks (place the closed-door tiles, not
# empty). Non-solid for A* to match the arena's own doors.
func close_boss_gap():
	var bottom = _boss_box_tiles["bottom"]
	_set_boss_wall(Vector2i(DOOR_COLS[0], bottom), DOOR_CLOSED_L, false)
	_set_boss_wall(Vector2i(DOOR_COLS[1], bottom), DOOR_CLOSED_R, false)


# World position of the boss room's top door (centre of the 2-tile door), used
# to relocate the exit there for boss waves.
func boss_top_door_position() -> Vector2:
	var top = _boss_box_tiles["top"]
	var a = get_position_from_tilemap(Vector2i(DOOR_COLS[0], top))
	var b = get_position_from_tilemap(Vector2i(DOOR_COLS[1], top))
	return (a + b) / 2.0


# Open the top door of the boss room (on defeat) so the sharks can escape upward.
# Clears the two door tiles and frees them for A* pathing; the room stays intact.
func open_boss_top_door():
	var top = _boss_box_tiles["top"]
	for x in DOOR_COLS:
		var cell = Vector2i(x, top)
		walls_layer.set_cell(cell, -1)
		obstacle_dict.erase(cell)
		if astar and astar.is_in_boundsv(cell):
			astar.set_point_solid(cell, false)


func _set_boss_wall(cell: Vector2i, atlas: Vector2i, astar_solid := true):
	walls_layer.set_cell(cell, WALL_SOURCE, atlas)
	obstacle_dict[cell] = true
	# Door cells are left non-solid for A* (like the arena's own doors) so the
	# key-holder can path to/through the door; physical collision opens it.
	if astar_solid and astar and astar.is_in_boundsv(cell):
		astar.set_point_solid(cell, true)
	_boss_wall_cells.append(cell)


# Tear down the boss walls (on defeat) so the escape-to-exit pathing is clear.
func clear_boss_walls():
	for cell in _boss_wall_cells:
		walls_layer.set_cell(cell, -1)
		obstacle_dict.erase(cell)
		if astar and astar.is_in_boundsv(cell):
			astar.set_point_solid(cell, false)
	_boss_wall_cells.clear()
	_boss_room_active = false


func add_obstacle():
	var obstacle_start_x
	var obstacle_start_y
	var obstacle_size_x
	var obstacle_size_y
	var valid_placement = false

	while !valid_placement:
		obstacle_start_x = randi_range(5, 55)
		obstacle_start_y = randi_range(5, 25)

		obstacle_size_x = randi_range(
			constants.ARENA_OBSTACLE_SIZE_MINIMUM, constants.ARENA_OBSTACLE_SIZE_MAXIMUM
		)
		obstacle_size_y = randi_range(
			constants.ARENA_OBSTACLE_SIZE_MINIMUM, constants.ARENA_OBSTACLE_SIZE_MAXIMUM
		)

		if !overlapping_obstacle(
			Vector2i(obstacle_start_x, obstacle_start_y), Vector2i(obstacle_size_x, obstacle_size_y)
		):
			valid_placement = true

	# Top left edge
	items_layer.set_cell(Vector2(obstacle_start_x, obstacle_start_y), 1, Vector2i(0, 10))
	astar.set_point_solid(Vector2(obstacle_start_x, obstacle_start_y), true)

	for i in range(1, obstacle_size_x - 1):
		items_layer.set_cell(Vector2(obstacle_start_x + i, obstacle_start_y), 1, Vector2i(1, 10))
		astar.set_point_solid(Vector2(obstacle_start_x + i, obstacle_start_y), true)

	# Top right edge
	items_layer.set_cell(
		Vector2(obstacle_start_x + (obstacle_size_x - 1), obstacle_start_y), 1, Vector2i(3, 10)
	)
	astar.set_point_solid(Vector2(obstacle_start_x + (obstacle_size_x - 1), obstacle_start_y), true)

	# Vertical edges
	for i in range(1, obstacle_size_y - 1):
		items_layer.set_cell(Vector2(obstacle_start_x, obstacle_start_y + i), 1, Vector2i(2, 11))
		items_layer.set_cell(
			Vector2(obstacle_start_x + (obstacle_size_x - 1), obstacle_start_y + i),
			1,
			Vector2i(2, 11)
		)
		astar.set_point_solid(Vector2(obstacle_start_x, obstacle_start_y + i), true)
		astar.set_point_solid(
			Vector2(obstacle_start_x + (obstacle_size_x - 1), obstacle_start_y + i), true
		)

	# Bottom left edge
	items_layer.set_cell(
		Vector2(obstacle_start_x, obstacle_start_y + (obstacle_size_y - 1)), 1, Vector2i(1, 12)
	)
	astar.set_point_solid(Vector2(obstacle_start_x, obstacle_start_y + (obstacle_size_y - 1)), true)

	for i in range(1, obstacle_size_x - 1):
		items_layer.set_cell(
			Vector2(obstacle_start_x + i, obstacle_start_y + (obstacle_size_y - 1)),
			1,
			Vector2i(1, 10)
		)
		astar.set_point_solid(
			Vector2(obstacle_start_x + i, obstacle_start_y + (obstacle_size_y - 1)), true
		)

	# Bottom right edge
	items_layer.set_cell(
		Vector2(obstacle_start_x + (obstacle_size_x - 1), obstacle_start_y + (obstacle_size_y - 1)),
		1,
		Vector2(3, 12)
	)
	astar.set_point_solid(
		Vector2(obstacle_start_x + (obstacle_size_x - 1), obstacle_start_y + (obstacle_size_y - 1)),
		true
	)

	# Set obstacles in obstacle_dict
	for x in range(obstacle_start_x - 1, obstacle_start_x + obstacle_size_x + 1):
		for y in range(obstacle_start_y - 1, obstacle_start_y + obstacle_size_y + 1):
			obstacle_dict[Vector2i(x, y)] = true


func reset_arena_floor(player_count := 1):
	for tile in obstacle_dict:
		items_layer.set_cell(tile, -1)

	# Remove any boss-room walls from a previous boss wave (they live on the Walls
	# layer, so the obstacle sweep above doesn't touch them).
	clear_boss_walls()

	reset_obstacle_dictionary(player_count)
	reset_astar_grid()


func reset_obstacle_dictionary(player_count := 1):
	obstacle_dict.clear()

	# Reserve player 1's swim-in lane (the door columns) so obstacles never
	# block it and trap the shark.
	for y in range(3, 32):
		obstacle_dict[Vector2i(31, y)] = true
		obstacle_dict[Vector2i(32, y)] = true

	# In 2-player, also reserve player 2's swim-in lane (its start marker sits
	# ~3 tiles right of player 1's).
	if player_count >= 2:
		for y in range(3, 32):
			obstacle_dict[Vector2i(35, y)] = true
			obstacle_dict[Vector2i(36, y)] = true


func reset_astar_grid():
	astar = AStarGrid2D.new()
	#astar.size = Vector2i(60,42)
	astar.region = Rect2i(0, 0, 65, 42)
	astar.cell_size = Vector2(16, 16)
	astar.update()


func astar_route(source_vector, destination_vector):
	var route = astar.get_id_path(source_vector, destination_vector)
	return route


func overlapping_obstacle(obstacle_pos, obstacle_size):
	for x in range(obstacle_pos.x - 1, obstacle_pos.x + obstacle_size.x + 1):
		for y in range(obstacle_pos.y - 1, obstacle_pos.y + obstacle_size.y + 1):
			if obstacle_dict.get(Vector2i(x, y), false):
				return true

	return false


func conflict_with_obstacle(coords):
	var map_coords = items_layer.local_to_map(items_layer.to_local(coords))

	if obstacle_dict.get(Vector2i(map_coords.x, map_coords.y)):
		return true

	return false


func get_tilemap_coords(coords):
	return items_layer.local_to_map(items_layer.to_local(coords))


func get_position_from_tilemap(coords):
	return items_layer.to_global(items_layer.map_to_local(coords))


func get_astar_route_from_positions(source, target):
	var source_map_coords = get_tilemap_coords(source)
	var destination_map_coords = get_tilemap_coords(target)

	return astar_route(source_map_coords, destination_map_coords)
