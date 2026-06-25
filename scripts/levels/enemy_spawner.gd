extends Node

@export var enemy_scenes: Array[PackedScene] = []
@export var enemies_per_floor_min: int = 2
@export var enemies_per_floor_max: int = 3
@export var patrol_point_count: int = 4

func spawn_enemies(rooms: Array[Room]) -> void:
	_clear_enemies()

	if RunManager.current_floor != 1:
		return

	var total = randi_range(enemies_per_floor_min, enemies_per_floor_max)
	var candidates: Array[Room] = []
	for i in range(1, rooms.size()):
		candidates.append(rooms[i])
	candidates.shuffle()

	var spawned := 0
	for room in candidates:
		if spawned >= total:
			break
		if enemy_scenes.is_empty():
			break

		var enemy_scene = enemy_scenes[randi() % enemy_scenes.size()]
		var enemy = enemy_scene.instantiate()
		var spawn_points = room.get_spawn_points()
		if spawn_points.size() > 0:
			enemy.global_position = spawn_points[randi() % spawn_points.size()].global_position
		else:
			enemy.global_position = room.global_position

		var patrol_pts: Array[Vector2] = []
		for k in patrol_point_count:
			var offset = Vector2(randf_range(-280, 280), randf_range(-180, 180))
			patrol_pts.append(room.global_position + offset)
		enemy.patrol_points = patrol_pts

		enemy.died.connect(room.check_cleared)
		enemy.z_index = 5
		add_child(enemy)
		room.enemies.append(enemy)
		spawned += 1

func _clear_enemies() -> void:
	for child in get_children():
		if child is Enemy:
			child.queue_free()
