extends Node2D
class_name LevelGenerator

@export var room_templates: Array[PackedScene] = []
@export var portal_template: PackedScene
@export var room_size: Vector2 = Vector2(800, 600)
@export var generation_radius: int = 2
@export var cleanup_radius: int = 4
@export var portal_interval_min: int = 10
@export var portal_interval_max: int = 15

const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

var room_map: Dictionary = {}
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
	_ensure_area_around(player_grid)
	_place_player()
	_place_enemies_and_items()

func _clear_floor() -> void:
	for room in room_map.values():
		if is_instance_valid(room):
			room.queue_free()
	room_map.clear()

func _world_to_grid(pos: Vector2) -> Vector2i:
	return Vector2i(roundi(pos.x / room_size.x), roundi(pos.y / room_size.y))

func _grid_to_world(grid: Vector2i) -> Vector2:
	return Vector2(grid) * room_size

func _ensure_area_around(center: Vector2i) -> void:
	for dx in range(-generation_radius, generation_radius + 1):
		for dy in range(-generation_radius, generation_radius + 1):
			var gp = center + Vector2i(dx, dy)
			if not room_map.has(gp):
				_generate_room_at(gp)

func _generate_room_at(grid_pos: Vector2i) -> Room:
	var template = room_templates[randi() % room_templates.size()]
	var room = template.instantiate()
	room.global_position = _grid_to_world(grid_pos)
	add_child(room)
	room_map[grid_pos] = room

	for dir in DIRS:
		var neighbor_grid = grid_pos + dir
		if room_map.has(neighbor_grid):
			var neighbor = room_map[neighbor_grid] as Room
			if not (neighbor in room.connections):
				room.add_connection(neighbor)
				neighbor.add_connection(room)
			var room_dir = _vector2i_to_door_dir(dir)
			var opp_dir = _vector2i_to_door_dir(-dir)
			if not room.has_door(room_dir):
				room.add_door(room_dir)
			if not neighbor.has_door(opp_dir):
				neighbor.add_door(opp_dir)

	rooms_since_portal += 1
	if rooms_since_portal >= portal_target and portal_template:
		_place_portal_in(room)
		rooms_since_portal = 0
		portal_target = randi_range(portal_interval_min, portal_interval_max)

	return room

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
		for other in room.connections:
			if not is_instance_valid(other):
				continue
			other.connections.erase(room)
			var dir = _get_dir_between(gp, _world_to_grid(other.global_position))
			_disable_door(other, dir)
		room.queue_free()
		room_map.erase(gp)

func _disable_door(room: Room, dir: int) -> void:
	match dir:
		0: room.has_door_top = false; room.door_top.visible = false
		1: room.has_door_bottom = false; room.door_bottom.visible = false
		2: room.has_door_left = false; room.door_left.visible = false
		3: room.has_door_right = false; room.door_right.visible = false
	room._build_wall_collisions()

func _vector2i_to_door_dir(v: Vector2i) -> int:
	if v == Vector2i.UP: return 0
	if v == Vector2i.DOWN: return 1
	if v == Vector2i.LEFT: return 2
	return 3

func _get_dir_between(from: Vector2i, to: Vector2i) -> int:
	var diff = to - from
	if diff == Vector2i.UP: return 0
	if diff == Vector2i.DOWN: return 1
	if diff == Vector2i.LEFT: return 2
	return 3

func _place_player() -> void:
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node and room_map.has(Vector2i.ZERO):
		var spawn = room_map[Vector2i.ZERO] as Room
		player_node.global_position = spawn.global_position + Vector2(0, -50)

func _place_enemies_and_items() -> void:
	var rooms_array: Array[Room] = []
	for room in room_map.values():
		rooms_array.append(room)

	var enemy_spawner = get_node_or_null("EnemySpawner")
	if enemy_spawner:
		enemy_spawner.spawn_enemies(rooms_array)

	var item_spawner = get_node_or_null("ItemSpawner")
	if item_spawner:
		item_spawner.spawn_items(rooms_array)
