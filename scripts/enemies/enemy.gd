extends CharacterBody2D
class_name Enemy

signal died

enum EnemyType { WANDERER, STALKER, HOWLER, CLUMP }

@export var enemy_type: EnemyType = EnemyType.WANDERER
@export var max_health: float = 50.0
@export var move_speed: float = 120.0
@export var contact_damage: float = 10.0
@export var detection_range: float = 400.0
@export var attack_range: float = 60.0
@export var attack_damage: float = 15.0
@export var attack_cooldown: float = 1.0
@export var patrol_points: Array[Vector2] = []
@export var sanity_drain_rate: float = 2.0

var health: float
var current_state: String = "idle"
var player: Player = null
var attack_timer: float = 0.0
var patrol_index: int = 0
var is_dead: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_area: Area2D = $AttackArea
@onready var state_timer: Timer = $StateTimer

func _ready() -> void:
	health = max_health
	add_to_group("enemy")
	_generate_sprite()
	if detection_area:
		detection_area.body_entered.connect(_on_player_detected)
		detection_area.body_exited.connect(_on_player_lost)
	if attack_area:
		attack_area.body_entered.connect(_on_player_in_attack_range)
		attack_area.body_exited.connect(_on_player_out_attack_range)
	if state_timer:
		state_timer.timeout.connect(_on_state_timer_timeout)
	_enter_state("idle")

func _generate_sprite() -> void:
	var s = 32
	var img = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var body_c = Color(0.55, 0.50, 0.45)
	var eye_c = Color(0.9, 0.85, 0.7)
	var pupil_c = Color(0.1, 0.05, 0.05)

	for y in range(4, 28):
		for x in range(4, 28):
			var dx = x - 16
			var dy = y - 16
			if dx * dx + dy * dy < 130:
				img.set_pixel(x, y, body_c)
	for y in range(8, 12):
		img.set_pixel(12, y, eye_c)
		img.set_pixel(13, y, pupil_c)
		img.set_pixel(18, y, eye_c)
		img.set_pixel(19, y, pupil_c)
	for y in range(16, 20):
		for x in range(10, 22):
			img.set_pixel(x, y, Color(0.35, 0.30, 0.28))

	var big = Image.create(s * 2, s * 2, false, Image.FORMAT_RGBA8)
	big.fill(Color(0, 0, 0, 0))
	for fy in range(s):
		for fx in range(s):
			var c = img.get_pixel(fx, fy)
			if c.a > 0:
				for dy in range(2):
					for dx in range(2):
						big.set_pixel(fx * 2 + dx, fy * 2 + dy, c)

	var tex = ImageTexture.create_from_image(big)
	sprite.texture = tex
	sprite.offset = Vector2(-s * 2 / 2.0, -s * 2 / 2.0)

func _physics_process(delta: float) -> void:
	if is_dead or GameManager.current_state != GameManager.GameState.PLAYING:
		return

	attack_timer = max(0.0, attack_timer - delta)

	match current_state:
		"idle":
			velocity = velocity.move_toward(Vector2.ZERO, move_speed * 5 * delta)
		"patrol":
			_patrol(delta)
		"chase":
			_chase(delta)
		"attack":
			_attack()

	move_and_slide()

func _enter_state(state: String) -> void:
	current_state = state
	match state:
		"idle":
			if state_timer:
				state_timer.start(randf_range(1.0, 3.0))
		"patrol":
			patrol_index = 0
		"chase":
			pass
		"attack":
			pass

func _patrol(delta: float) -> void:
	if patrol_points.is_empty():
		_enter_state("idle")
		return

	var target = patrol_points[patrol_index]
	var dir = (target - global_position).normalized()
	velocity = dir * move_speed * 0.5

	if global_position.distance_to(target) < 10.0:
		patrol_index = (patrol_index + 1) % patrol_points.size()
		if patrol_index == 0:
			_enter_state("idle")

func _chase(delta: float) -> void:
	if not player:
		_enter_state("idle")
		return

	var dir = (player.global_position - global_position).normalized()
	velocity = dir * move_speed

	if global_position.distance_to(player.global_position) < 150.0:
		RunManager.modify_sanity(-sanity_drain_rate * delta)

func _attack() -> void:
	velocity = Vector2.ZERO
	if attack_timer <= 0.0 and player:
		player.take_damage(attack_damage)
		attack_timer = attack_cooldown

func _on_player_detected(body: Node2D) -> void:
	if body is Player:
		player = body
		if current_state in ["idle", "patrol"]:
			_enter_state("chase")

func _on_player_lost(body: Node2D) -> void:
	if body is Player:
		player = null
		_enter_state("patrol")

func _on_player_in_attack_range(body: Node2D) -> void:
	if body is Player and current_state == "chase":
		_enter_state("attack")

func _on_player_out_attack_range(body: Node2D) -> void:
	if body is Player and current_state == "attack":
		_enter_state("chase")

func _on_state_timer_timeout() -> void:
	if current_state == "idle":
		if not patrol_points.is_empty():
			_enter_state("patrol")
		else:
			state_timer.start(randf_range(1.0, 3.0))

func take_damage(amount: float) -> void:
	if is_dead:
		return
	health -= amount
	if health <= 0:
		die()
	elif current_state in ["idle", "patrol"]:
		_enter_state("chase")

func die() -> void:
	is_dead = true
	RunManager.add_kill()
	died.emit()
	queue_free()
