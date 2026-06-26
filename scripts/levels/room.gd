extends Node2D
class_name Room

@export var room_id: int = 0
@export var connections: Array[Room] = []

var enemies: Array[Enemy] = []
var items: Array[Node2D] = []
var is_cleared: bool = false
var is_lockable_room: bool = false
var is_chest_room: bool = false
var has_door_top: bool = false
var has_door_bottom: bool = false
var has_door_left: bool = false
var has_door_right: bool = false
var door_locked_top: bool = false
var door_locked_bottom: bool = false
var door_locked_left: bool = false
var door_locked_right: bool = false
var layout_archetype: StringName = &"claustrophobic"

var room_half_w: float = 400.0
var room_half_h: float = 300.0
var layout_features: Array[Node] = []

const DOOR_GAP: float = 100.0
const WALL_THICKNESS: float = 8.0

@onready var floor_rect: ColorRect = $Floor
@onready var static_body: StaticBody2D = $StaticBody2D
@onready var door_top: ColorRect = $DoorTop
@onready var door_bottom: ColorRect = $DoorBottom
@onready var door_left: ColorRect = $DoorLeft
@onready var door_right: ColorRect = $DoorRight
@onready var wall_top: ColorRect = $Walls/WallTop
@onready var wall_bottom: ColorRect = $Walls/WallBottom
@onready var wall_left: ColorRect = $Walls/WallLeft
@onready var wall_right: ColorRect = $Walls/WallRight
@onready var lock_collision_top: CollisionShape2D = $StaticBody2D/LockCollisionTop
@onready var lock_collision_bottom: CollisionShape2D = $StaticBody2D/LockCollisionBottom
@onready var lock_collision_left: CollisionShape2D = $StaticBody2D/LockCollisionLeft
@onready var lock_collision_right: CollisionShape2D = $StaticBody2D/LockCollisionRight


func _ready() -> void:
	_build_wall_collisions()


func configure(
	w: float, h: float, floor_col: Color, wall_col: Color, archetype: StringName = &"claustrophobic"
) -> void:
	room_half_w = w / 2.0
	room_half_h = h / 2.0
	layout_archetype = archetype

	floor_rect.offset_left = -room_half_w
	floor_rect.offset_top = -room_half_h
	floor_rect.offset_right = room_half_w
	floor_rect.offset_bottom = room_half_h
	floor_rect.color = floor_col

	wall_top.offset_left = -room_half_w
	wall_top.offset_top = -room_half_h - WALL_THICKNESS
	wall_top.offset_right = room_half_w
	wall_top.offset_bottom = -room_half_h

	wall_bottom.offset_left = -room_half_w
	wall_bottom.offset_top = room_half_h
	wall_bottom.offset_right = room_half_w
	wall_bottom.offset_bottom = room_half_h + WALL_THICKNESS

	wall_left.offset_left = -room_half_w - WALL_THICKNESS
	wall_left.offset_top = -room_half_h
	wall_left.offset_right = -room_half_w
	wall_left.offset_bottom = room_half_h

	wall_right.offset_left = room_half_w
	wall_right.offset_top = -room_half_h
	wall_right.offset_right = room_half_w + WALL_THICKNESS
	wall_right.offset_bottom = room_half_h

	for w_ch in [wall_top, wall_bottom, wall_left, wall_right]:
		w_ch.color = wall_col

	lock_collision_top.position = Vector2(0, -room_half_h + WALL_THICKNESS / 2.0)
	lock_collision_bottom.position = Vector2(0, room_half_h - WALL_THICKNESS / 2.0)
	lock_collision_left.position = Vector2(-room_half_w + WALL_THICKNESS / 2.0, 0)
	lock_collision_right.position = Vector2(room_half_w - WALL_THICKNESS / 2.0, 0)

	_build_wall_collisions()
	_apply_layout_archetype()


func spawn_obstacles() -> void:
	_add_random_pillars(randi_range(1, 3))


func _apply_layout_archetype() -> void:
	_clear_layout_features()
	match layout_archetype:
		&"pillar_hall":
			_add_pillar_hall()
		&"ring_room":
			_add_ring_room()
		&"service_maze":
			_add_service_maze()
		&"storage_bays":
			_add_storage_bays()
		_:
			if room_half_w >= 400 and room_half_h >= 300:
				_add_random_pillars(randi_range(1, 2))


func _clear_layout_features() -> void:
	for feature in layout_features:
		if is_instance_valid(feature):
			feature.queue_free()
	layout_features.clear()


func _add_pillar_hall() -> void:
	var x = minf(room_half_w * 0.38, 280.0)
	var y = minf(room_half_h * 0.32, 190.0)
	for pos in [Vector2(-x, -y), Vector2(x, -y), Vector2(-x, y), Vector2(x, y)]:
		_add_obstacle_rect(pos, Vector2(54, 54), wall_top.color.darkened(0.28))


func _add_ring_room() -> void:
	var w = minf(room_half_w * 0.78, 360.0)
	var h = minf(room_half_h * 0.58, 240.0)
	_add_obstacle_rect(Vector2.ZERO, Vector2(w, h), wall_top.color.darkened(0.22))


func _add_service_maze() -> void:
	var wall_color = wall_top.color.darkened(0.18)
	_add_obstacle_rect(
		Vector2(-room_half_w * 0.24, -room_half_h * 0.30),
		Vector2(room_half_w * 0.70, 34),
		wall_color
	)
	_add_obstacle_rect(
		Vector2(room_half_w * 0.25, room_half_h * 0.20), Vector2(room_half_w * 0.62, 34), wall_color
	)
	_add_obstacle_rect(
		Vector2(room_half_w * 0.16, -room_half_h * 0.03),
		Vector2(34, room_half_h * 0.52),
		wall_color
	)


func _add_storage_bays() -> void:
	var wall_color = wall_top.color.darkened(0.25)
	var bay_w = minf(92.0, room_half_w * 0.22)
	var bay_h = minf(120.0, room_half_h * 0.34)
	for y in [-room_half_h * 0.38, 0.0, room_half_h * 0.38]:
		_add_obstacle_rect(Vector2(-room_half_w * 0.52, y), Vector2(bay_w, bay_h), wall_color)
		_add_obstacle_rect(Vector2(room_half_w * 0.52, y), Vector2(bay_w, bay_h), wall_color)


func _add_random_pillars(count: int) -> void:
	for i in count:
		var pw = randi_range(20, 60)
		var ph = randi_range(20, 60)
		var pos = Vector2(
			randf_range(-room_half_w * 0.6, room_half_w * 0.6),
			randf_range(-room_half_h * 0.6, room_half_h * 0.6)
		)
		_add_obstacle_rect(pos, Vector2(pw, ph), wall_top.color.darkened(0.3))


func _add_obstacle_rect(pos: Vector2, size: Vector2, color: Color) -> void:
	var obstacle = Node2D.new()
	obstacle.position = pos
	add_child(obstacle)
	layout_features.append(obstacle)

	var pillar = ColorRect.new()
	pillar.offset_left = -size.x / 2.0
	pillar.offset_top = -size.y / 2.0
	pillar.offset_right = size.x / 2.0
	pillar.offset_bottom = size.y / 2.0
	pillar.color = color
	obstacle.add_child(pillar)

	var pillar_body = StaticBody2D.new()
	pillar_body.collision_layer = 1
	var shape = RectangleShape2D.new()
	shape.size = size
	var col = CollisionShape2D.new()
	col.shape = shape
	pillar_body.add_child(col)
	obstacle.add_child(pillar_body)


func add_connection(other: Room) -> void:
	if other in connections:
		return
	connections.append(other)


func make_lockable() -> void:
	is_lockable_room = true
	_update_door_colors()


func add_door(dir: int) -> void:
	match dir:
		0:
			has_door_top = true
			door_top.visible = true
		1:
			has_door_bottom = true
			door_bottom.visible = true
		2:
			has_door_left = true
			door_left.visible = true
		3:
			has_door_right = true
			door_right.visible = true
	_build_wall_collisions()
	_update_door_colors()
	_update_door_positions()


func _update_door_positions() -> void:
	door_top.offset_top = -room_half_h - WALL_THICKNESS
	door_top.offset_bottom = -room_half_h
	door_bottom.offset_top = room_half_h
	door_bottom.offset_bottom = room_half_h + WALL_THICKNESS
	door_left.offset_left = -room_half_w - WALL_THICKNESS
	door_left.offset_right = -room_half_w
	door_right.offset_left = room_half_w
	door_right.offset_right = room_half_w + WALL_THICKNESS


func has_door(dir: int) -> bool:
	match dir:
		0:
			return has_door_top
		1:
			return has_door_bottom
		2:
			return has_door_left
		3:
			return has_door_right
	return false


func _update_door_colors() -> void:
	if is_lockable_room:
		_update_lockable_door(door_top, door_locked_top)
		_update_lockable_door(door_bottom, door_locked_bottom)
		_update_lockable_door(door_left, door_locked_left)
		_update_lockable_door(door_right, door_locked_right)


func _update_lockable_door(door: ColorRect, locked: bool) -> void:
	if not door.visible:
		return
	door.color = Color(0.7, 0.2, 0.2, 1) if locked else Color(0.5, 0.5, 0.5, 1)


func get_nearest_door_dir(global_pos: Vector2) -> int:
	if not is_lockable_room:
		return -1
	var local = to_local(global_pos)
	var best_dir := -1
	var best_dist := 80.0
	var checks = [
		[0, Vector2(0, -room_half_h)],
		[1, Vector2(0, room_half_h)],
		[2, Vector2(-room_half_w, 0)],
		[3, Vector2(room_half_w, 0)]
	]
	for c in checks:
		var d = c[0] as int
		if not has_door(d):
			continue
		var dist = local.distance_to(c[1] as Vector2)
		if dist < best_dist:
			best_dist = dist
			best_dir = d
	return best_dir


func toggle_door_lock(dir: int) -> bool:
	if not is_lockable_room:
		return false
	match dir:
		0:
			door_locked_top = not door_locked_top
		1:
			door_locked_bottom = not door_locked_bottom
		2:
			door_locked_left = not door_locked_left
		3:
			door_locked_right = not door_locked_right
	_update_door_colors()
	_update_lock_collisions()
	return is_door_locked(dir)


func is_door_locked(dir: int) -> bool:
	match dir:
		0:
			return door_locked_top
		1:
			return door_locked_bottom
		2:
			return door_locked_left
		3:
			return door_locked_right
	return false


func _update_lock_collisions() -> void:
	lock_collision_top.disabled = not door_locked_top
	lock_collision_bottom.disabled = not door_locked_bottom
	lock_collision_left.disabled = not door_locked_left
	lock_collision_right.disabled = not door_locked_right


func _clear_collisions() -> void:
	for child in static_body.get_children():
		if child is CollisionShape2D and not child.name.begins_with("Lock"):
			child.queue_free()


func _build_wall_collisions() -> void:
	_clear_collisions()
	var hw = room_half_w
	var hh = room_half_h
	var wt = WALL_THICKNESS
	if not has_door_top:
		_add_collision_rect(Vector2(0, -hh - wt / 2.0), Vector2(hw * 2, wt))
	else:
		_add_top_bottom_segments(-hh - wt / 2.0, hw, wt)
	if not has_door_bottom:
		_add_collision_rect(Vector2(0, hh + wt / 2.0), Vector2(hw * 2, wt))
	else:
		_add_top_bottom_segments(hh + wt / 2.0, hw, wt)
	if not has_door_left:
		_add_collision_rect(Vector2(-hw - wt / 2.0, 0), Vector2(wt, hh * 2))
	else:
		_add_left_right_segments(-hw - wt / 2.0, hh, wt)
	if not has_door_right:
		_add_collision_rect(Vector2(hw + wt / 2.0, 0), Vector2(wt, hh * 2))
	else:
		_add_left_right_segments(hw + wt / 2.0, hh, wt)


func _add_top_bottom_segments(y: float, hw: float, wt: float) -> void:
	var half_gap = DOOR_GAP / 2.0
	var seg_width = hw - half_gap
	_add_collision_rect(Vector2(-hw + seg_width / 2.0, y), Vector2(seg_width, wt))
	_add_collision_rect(Vector2(hw - seg_width / 2.0, y), Vector2(seg_width, wt))


func _add_left_right_segments(x: float, hh: float, wt: float) -> void:
	var half_gap = DOOR_GAP / 2.0
	var seg_height = hh - half_gap
	_add_collision_rect(Vector2(x, -hh + seg_height / 2.0), Vector2(wt, seg_height))
	_add_collision_rect(Vector2(x, hh - seg_height / 2.0), Vector2(wt, seg_height))


func _add_collision_rect(pos: Vector2, size: Vector2) -> void:
	var shape = RectangleShape2D.new()
	shape.size = size
	var col = CollisionShape2D.new()
	col.shape = shape
	col.position = pos
	static_body.add_child(col)


func on_player_enter() -> void:
	pass


func on_player_exit() -> void:
	pass


func check_cleared() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_dead:
			return
	is_cleared = true
	RunManager.add_room_cleared()


func get_spawn_points() -> Array[Marker2D]:
	var points: Array[Marker2D] = []
	for child in get_children():
		if child is Marker2D and child.name.begins_with("SpawnPoint"):
			points.append(child)
	return points
