extends TileMap

var ObstacleDict: Dictionary
var ArenaFloorDefault: Array
var astar: AStarGrid2D


# Called when the node enters the scene tree for the first time.
func _ready():
    pass


# Top / Bottom door functions.
func open_top_door():
    set_cell(2, Vector2(31, 2), -1, Vector2i(9, 7))

    set_cell(2, Vector2(32, 2), -1, Vector2i(9, 7))


func close_top_door():
    set_cell(2, Vector2(31, 2), 0, Vector2i(6, 6))

    set_cell(2, Vector2(32, 2), 0, Vector2i(7, 6))


func open_bottom_door():
    set_cell(2, Vector2(31, 33), -1, Vector2i(6, 6))

    set_cell(2, Vector2(32, 33), -1, Vector2i(7, 6))


func close_bottom_door():
    set_cell(2, Vector2(31, 33), 0, Vector2i(6, 6))

    set_cell(2, Vector2(32, 33), 0, Vector2i(7, 6))


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
    set_cell(2, Vector2(obstacle_start_x, obstacle_start_y), 1, Vector2i(0, 10))
    astar.set_point_solid(Vector2(obstacle_start_x, obstacle_start_y), true)

    for i in range(1, obstacle_size_x - 1):
        set_cell(2, Vector2(obstacle_start_x + i, obstacle_start_y), 1, Vector2i(1, 10))
        astar.set_point_solid(Vector2(obstacle_start_x + i, obstacle_start_y), true)

    # Top right edge
    set_cell(
        2, Vector2(obstacle_start_x + (obstacle_size_x - 1), obstacle_start_y), 1, Vector2i(3, 10)
    )
    astar.set_point_solid(Vector2(obstacle_start_x + (obstacle_size_x - 1), obstacle_start_y), true)

    # Vertical edges
    for i in range(1, obstacle_size_y - 1):
        set_cell(2, Vector2(obstacle_start_x, obstacle_start_y + i), 1, Vector2i(2, 11))
        set_cell(
            2,
            Vector2(obstacle_start_x + (obstacle_size_x - 1), obstacle_start_y + i),
            1,
            Vector2i(2, 11)
        )
        astar.set_point_solid(Vector2(obstacle_start_x, obstacle_start_y + i), true)
        astar.set_point_solid(
            Vector2(obstacle_start_x + (obstacle_size_x - 1), obstacle_start_y + i), true
        )

    # Bottom left edge
    set_cell(
        2, Vector2(obstacle_start_x, obstacle_start_y + (obstacle_size_y - 1)), 1, Vector2i(1, 12)
    )
    astar.set_point_solid(Vector2(obstacle_start_x, obstacle_start_y + (obstacle_size_y - 1)), true)

    for i in range(1, obstacle_size_x - 1):
        set_cell(
            2,
            Vector2(obstacle_start_x + i, obstacle_start_y + (obstacle_size_y - 1)),
            1,
            Vector2i(1, 10)
        )
        astar.set_point_solid(
            Vector2(obstacle_start_x + i, obstacle_start_y + (obstacle_size_y - 1)), true
        )

    # Bottom right edge
    set_cell(
        2,
        Vector2(obstacle_start_x + (obstacle_size_x - 1), obstacle_start_y + (obstacle_size_y - 1)),
        1,
        Vector2(3, 12)
    )
    astar.set_point_solid(
        Vector2(obstacle_start_x + (obstacle_size_x - 1), obstacle_start_y + (obstacle_size_y - 1)),
        true
    )

    # Set obstacles in ObstacleDict
    for x in range(obstacle_start_x - 1, obstacle_start_x + obstacle_size_x + 1):
        for y in range(obstacle_start_y - 1, obstacle_start_y + obstacle_size_y + 1):
            ObstacleDict[Vector2i(x, y)] = true


func reset_arena_floor():
    for tile in ObstacleDict:
        set_cell(2, tile, -1)

    reset_obstacle_dictionary()
    reset_astar_grid()


func reset_obstacle_dictionary():
    ObstacleDict.clear()

    for y in range(3, 32):
        ObstacleDict[Vector2i(31, y)] = true
        ObstacleDict[Vector2i(32, y)] = true


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
            if ObstacleDict.get(Vector2i(x, y), false):
                return true

    return false


func conflict_with_obstacle(coords):
    var map_coords = local_to_map(to_local(coords))

    if ObstacleDict.get(Vector2i(map_coords.x, map_coords.y)):
        return true
    else:
        return false


func get_tilemap_coords(coords):
    return local_to_map(to_local(coords))


func get_position_from_tilemap(coords):
    return to_global(map_to_local(coords))


func get_astar_route_from_positions(source, target):
    var source_map_coords = get_tilemap_coords(source)
    var destination_map_coords = get_tilemap_coords(target)

    return astar_route(source_map_coords, destination_map_coords)
