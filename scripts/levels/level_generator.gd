extends Node2D
class_name LevelGenerator

@export var room_template: PackedScene
@export var portal_template: PackedScene
@export var chest_template: PackedScene
@export var generation_radius: int = 2
@export var cleanup_radius: int = 5
@export var portal_interval_min: int = 10
@export var portal_interval_max: int = 15

const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
const SIZES: Array[Vector2] = [
	Vector2(500, 400), Vector2(650, 500), Vector2(800, 600), Vector2(950, 700)
]
const GRID_SIZE: Vector2 = Vector2(1000, 750)
const CORRIDOR_WIDTH: float = 100.0
const CORRIDOR_WALL_THICKNESS: float = 12.0
const COLORS: Array[Color] = [
	Color(0.12, 0.10, 0.07),
	Color(0.10, 0.12, 0.10),
	Color(0.14, 0.11, 0.08),
	Color(0.09, 0.10, 0.12),
]
const ROOM_ARCHETYPES: Array[StringName] = [
	&"claustrophobic",
	&"pillar_hall",
	&"ring_room",
	&"service_maze",
	&"storage_bays",
]

var room_map: Dictionary = {}
var corridors: Array[Node2D] = []
var corridor_map: Dictionary = {}
var rooms_since_portal: int = 0
var portal_target: int = 0
var player_grid: Vector2i = Vector2i.ZERO


func _ready() -> void:
	generate_floor()


func _process(_delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	var player_node = get_tree().get_first_node_in_group("player")
	if not player_node:
		return
	var grid = _world_to_grid(player_node.global_position)
	if grid != player_grid:
		player_grid = grid
		_ensure_area_around(player_grid)
		_cleanup_distant(player_grid)


func generate_floor() -> void:
	_clear_floor()
	rooms_since_portal = 0
	portal_target = randi_range(portal_interval_min, portal_interval_max)
	player_grid = Vector2i.ZERO
	_ensure_area_around(player_grid, false)
	_place_player()
	_place_enemies_and_items()


func _clear_floor() -> void:
	for room in room_map.values():
		if is_instance_valid(room):
			room.queue_free()
	room_map.clear()
	for c in corridors:
		if is_instance_valid(c):
			c.queue_free()
	corridors.clear()
	corridor_map.clear()
	var enemy_spawner = get_node_or_null("EnemySpawner")
	if enemy_spawner and enemy_spawner.has_method("clear_enemies"):
		enemy_spawner.clear_enemies()
	var item_spawner = get_node_or_null("ItemSpawner")
	if item_spawner and item_spawner.has_method("clear_items"):
		item_spawner.clear_items()


func _world_to_grid(pos: Vector2) -> Vector2i:
	return Vector2i(roundi(pos.x / GRID_SIZE.x), roundi(pos.y / GRID_SIZE.y))


func _grid_to_world(grid: Vector2i) -> Vector2:
	return Vector2(grid) * GRID_SIZE


func _ensure_area_around(center: Vector2i, populate_new_rooms: bool = true) -> void:
	var new_rooms: Array[Room] = []
	for dx in range(-generation_radius, generation_radius + 1):
		for dy in range(-generation_radius, generation_radius + 1):
			var gp = center + Vector2i(dx, dy)
			if not room_map.has(gp):
				new_rooms.append(_generate_room_at(gp))
	if populate_new_rooms and not new_rooms.is_empty():
		_place_enemies_and_items(new_rooms, true)


func _generate_room_at(grid_pos: Vector2i) -> Room:
	var size = SIZES[randi() % SIZES.size()]
	var floor_col = COLORS[randi() % COLORS.size()]
	var wall_col = floor_col * 1.8
	var archetype = _pick_room_archetype(grid_pos, size)

	var room = room_template.instantiate() as Room
	room.global_position = _grid_to_world(grid_pos)
	add_child(room)
	room.configure(size.x, size.y, floor_col, wall_col, archetype)
	room_map[grid_pos] = room

	var neighbors: Array[Vector2i] = []
	for dir in DIRS:
		var neighbor_pos = grid_pos + dir
		if room_map.has(neighbor_pos) and (room_map[neighbor_pos] as Room).connections.size() < 3:
			neighbors.append(dir)

	var connect_count = _pick_connection_count(grid_pos, neighbors.size())
	neighbors.shuffle()
	for k in connect_count:
		var dir = neighbors[k]
		var n_pos = grid_pos + dir
		var neighbor = room_map[n_pos] as Room
		room.add_connection(neighbor)
		neighbor.add_connection(room)
		var room_dir = _vector2i_to_door_dir(dir)
		var opp_dir = _vector2i_to_door_dir(-dir)
		room.add_door(room_dir)
		neighbor.add_door(opp_dir)
		_add_corridor(grid_pos, n_pos, room, neighbor, room_dir)

	rooms_since_portal += 1
	if rooms_since_portal >= portal_target and portal_template:
		_place_portal_in(room)
		rooms_since_portal = 0
		portal_target = randi_range(portal_interval_min, portal_interval_max)

	if grid_pos != Vector2i.ZERO:
		var roll = randf()
		if roll < 0.12:
			room.make_lockable()
		elif roll < 0.25 and chest_template:
			room.is_chest_room = true
			_place_chest_in(room)

	return room


func _pick_room_archetype(grid_pos: Vector2i, size: Vector2) -> StringName:
	if grid_pos == Vector2i.ZERO:
		return &"pillar_hall"
	if size.x < 650 or size.y < 500:
		return &"claustrophobic"
	return ROOM_ARCHETYPES[randi() % ROOM_ARCHETYPES.size()]


func _pick_connection_count(grid_pos: Vector2i, neighbor_count: int) -> int:
	if neighbor_count == 0:
		return 0
	if grid_pos == Vector2i.ZERO:
		return mini(neighbor_count, 2)

	var roll = randf()
	if roll < 0.64:
		return 1
	if roll < 0.90:
		return mini(neighbor_count, 2)
	return mini(neighbor_count, 3)


func _add_corridor(a_grid: Vector2i, b_grid: Vector2i, a: Room, b: Room, dir: int) -> void:
	var key = _corridor_key(a_grid, b_grid)
	if corridor_map.has(key):
		return

	var a_edge: Vector2
	var b_edge: Vector2
	match dir:
		0:
			a_edge = a.global_position + Vector2(0, -a.room_half_h)
			b_edge = b.global_position + Vector2(0, b.room_half_h)
		1:
			a_edge = a.global_position + Vector2(0, a.room_half_h)
			b_edge = b.global_position + Vector2(0, -b.room_half_h)
		2:
			a_edge = a.global_position + Vector2(-a.room_half_w, 0)
			b_edge = b.global_position + Vector2(b.room_half_w, 0)
		_:
			a_edge = a.global_position + Vector2(a.room_half_w, 0)
			b_edge = b.global_position + Vector2(-b.room_half_w, 0)

	var corridor = Node2D.new()
	corridor.name = "Corridor_%s" % key.replace(":", "_").replace(",", "_")
	corridor.position = (a_edge + b_edge) / 2.0
	var dist = a_edge.distance_to(b_edge)
	var floor_rect = ColorRect.new()
	floor_rect.color = Color(0.18, 0.16, 0.12, 1)
	if dir == 0 or dir == 1:
		_configure_corridor_rect(floor_rect, Vector2(CORRIDOR_WIDTH, dist))
		_add_corridor_wall_pair(corridor, true, dist)
	else:
		_configure_corridor_rect(floor_rect, Vector2(dist, CORRIDOR_WIDTH))
		_add_corridor_wall_pair(corridor, false, dist)
	corridor.add_child(floor_rect)
	add_child(corridor)
	corridors.append(corridor)
	corridor_map[key] = corridor


func _configure_corridor_rect(rect: ColorRect, size: Vector2) -> void:
	rect.offset_left = -size.x / 2.0
	rect.offset_top = -size.y / 2.0
	rect.offset_right = size.x / 2.0
	rect.offset_bottom = size.y / 2.0


func _add_corridor_wall_pair(corridor: Node2D, vertical: bool, length: float) -> void:
	var body = StaticBody2D.new()
	body.collision_layer = 1
	corridor.add_child(body)
	if vertical:
		var x = CORRIDOR_WIDTH / 2.0 + CORRIDOR_WALL_THICKNESS / 2.0
		_add_corridor_collision(body, Vector2(-x, 0), Vector2(CORRIDOR_WALL_THICKNESS, length))
		_add_corridor_collision(body, Vector2(x, 0), Vector2(CORRIDOR_WALL_THICKNESS, length))
	else:
		var y = CORRIDOR_WIDTH / 2.0 + CORRIDOR_WALL_THICKNESS / 2.0
		_add_corridor_collision(body, Vector2(0, -y), Vector2(length, CORRIDOR_WALL_THICKNESS))
		_add_corridor_collision(body, Vector2(0, y), Vector2(length, CORRIDOR_WALL_THICKNESS))


func _add_corridor_collision(body: StaticBody2D, pos: Vector2, size: Vector2) -> void:
	var shape = RectangleShape2D.new()
	shape.size = size
	var collision = CollisionShape2D.new()
	collision.shape = shape
	collision.position = pos
	body.add_child(collision)


func _corridor_key(a: Vector2i, b: Vector2i) -> String:
	var first = a
	var second = b
	if a.x > b.x or (a.x == b.x and a.y > b.y):
		first = b
		second = a
	return "%d,%d:%d,%d" % [first.x, first.y, second.x, second.y]


func _remove_corridor(a: Vector2i, b: Vector2i) -> void:
	var key = _corridor_key(a, b)
	if not corridor_map.has(key):
		return
	var corridor = corridor_map[key] as Node2D
	if is_instance_valid(corridor):
		corridors.erase(corridor)
		corridor.queue_free()
	corridor_map.erase(key)


func _place_chest_in(room: Room) -> void:
	var chest = chest_template.instantiate()
	chest.position = Vector2(0, -50)
	room.add_child(chest)


func _place_portal_in(room: Room) -> void:
	for child in room.get_children():
		if child is Area2D and child.name.begins_with("Portal"):
			return
	var portal = portal_template.instantiate()
	portal.position = Vector2(0, 0)
	room.add_child(portal)


func _cleanup_distant(center: Vector2i) -> void:
	var to_remove: Array[Vector2i] = []
	for gp in room_map.keys():
		var dist = (gp - center).abs()
		if dist.x > cleanup_radius or dist.y > cleanup_radius:
			to_remove.append(gp)
	for gp in to_remove:
		var room = room_map[gp] as Room
		if not is_instance_valid(room):
			room_map.erase(gp)
			continue
		_clear_room_contents(room)
		for other in room.connections:
			if not is_instance_valid(other):
				continue
			var other_grid = _world_to_grid(other.global_position)
			_remove_corridor(gp, other_grid)
			other.connections.erase(room)
			var d = _get_dir_between(other_grid, gp)
			_disable_door(other, d)
		room.queue_free()
		room_map.erase(gp)


func _clear_room_contents(room: Room) -> void:
	for enemy in room.enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	room.enemies.clear()
	for item in room.items:
		if is_instance_valid(item):
			item.queue_free()
	room.items.clear()


func _disable_door(room: Room, dir: int) -> void:
	match dir:
		0:
			room.has_door_top = false
			room.door_locked_top = false
			room.door_top.visible = false
		1:
			room.has_door_bottom = false
			room.door_locked_bottom = false
			room.door_bottom.visible = false
		2:
			room.has_door_left = false
			room.door_locked_left = false
			room.door_left.visible = false
		3:
			room.has_door_right = false
			room.door_locked_right = false
			room.door_right.visible = false
	room._build_wall_collisions()
	room._update_lock_collisions()
	room._update_door_colors()


func _vector2i_to_door_dir(v: Vector2i) -> int:
	if v == Vector2i.UP:
		return 0
	if v == Vector2i.DOWN:
		return 1
	if v == Vector2i.LEFT:
		return 2
	return 3


func _get_dir_between(from: Vector2i, to: Vector2i) -> int:
	var diff = to - from
	if diff == Vector2i.UP:
		return 0
	if diff == Vector2i.DOWN:
		return 1
	if diff == Vector2i.LEFT:
		return 2
	return 3


func _place_player() -> void:
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node and room_map.has(Vector2i.ZERO):
		var spawn = room_map[Vector2i.ZERO] as Room
		player_node.global_position = spawn.global_position + Vector2(0, -50)


func _place_enemies_and_items(rooms: Array[Room] = [], append: bool = false) -> void:
	var rooms_array: Array[Room] = []
	if rooms.is_empty():
		for room in room_map.values():
			rooms_array.append(room)
	else:
		rooms_array = rooms
	var enemy_spawner = get_node_or_null("EnemySpawner")
	if enemy_spawner:
		if append and enemy_spawner.has_method("spawn_enemies_in_rooms"):
			enemy_spawner.spawn_enemies_in_rooms(rooms_array)
		else:
			enemy_spawner.spawn_enemies(rooms_array)
	var item_spawner = get_node_or_null("ItemSpawner")
	if item_spawner:
		if append and item_spawner.has_method("spawn_items_in_rooms"):
			item_spawner.spawn_items_in_rooms(rooms_array)
		else:
			item_spawner.spawn_items(rooms_array)
