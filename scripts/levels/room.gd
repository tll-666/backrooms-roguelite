extends Node2D
class_name Room

@export var room_id: int = 0
@export var is_exit: bool = false
@export var connections: Array[Room] = []

var enemies: Array[Enemy] = []
var items: Array[Node2D] = []
var is_cleared: bool = false
var has_door_top: bool = false
var has_door_bottom: bool = false
var has_door_left: bool = false
var has_door_right: bool = false

const DOOR_GAP: float = 100.0
const WALL_THICKNESS: float = 8.0
const ROOM_HALF_W: float = 400.0
const ROOM_HALF_H: float = 300.0

@onready var exit_indicator: Sprite2D = $ExitIndicator
@onready var static_body: StaticBody2D = $StaticBody2D
@onready var door_top: ColorRect = $DoorTop
@onready var door_bottom: ColorRect = $DoorBottom
@onready var door_left: ColorRect = $DoorLeft
@onready var door_right: ColorRect = $DoorRight

func _ready() -> void:
	if exit_indicator:
		exit_indicator.visible = is_exit
	_build_wall_collisions()

func add_connection(other: Room) -> void:
	if other in connections:
		return
	connections.append(other)

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

func has_door(dir: int) -> bool:
	match dir:
		0: return has_door_top
		1: return has_door_bottom
		2: return has_door_left
		3: return has_door_right
	return false

func _clear_collisions() -> void:
	for child in static_body.get_children():
		child.queue_free()

func _build_wall_collisions() -> void:
	_clear_collisions()

	var hw = ROOM_HALF_W
	var hh = ROOM_HALF_H
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
