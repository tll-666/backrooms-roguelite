extends CharacterBody2D
class_name Player

signal health_changed(current: float, max_hp: float)
signal stamina_changed(current: float, max_st: float)
signal ammo_changed(current: int, max_ammo: int)
signal weapon_changed(weapon: Weapon)

@export var move_speed: float = 300.0
@export var dash_speed: float = 900.0
@export var dash_duration: float = 0.12
@export var dash_cooldown: float = 1.5

var max_health: float = 100.0
var health: float = max_health
var max_stamina: float = 100.0
var stamina: float = max_stamina
var stamina_regen: float = 30.0
var dash_stamina_cost: float = 25.0
var current_weapon: Weapon = null
var weapon_inventory: Array[Weapon] = []
## 弹药储备：{"pistol": 数量, "stun": 数量, ...} — 装填时从此消耗
var ammo_reserves: Dictionary = {}
var has_flashlight: bool = true
var flashlight_on: bool = false
var hotbar: Array = [null, null, null, null]
var hotbar_selected: int = 0
var flashlight_body: Sprite2D

var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var is_dead: bool = false

# 开发者控制台状态（由 /god、/noclip 命令切换）。
var is_invincible: bool = false
var is_noclip: bool = false

const SPRITE_SIZE = 48
const SCALE = 2
const FRAME_IDLE = 0
const FRAME_WALK1 = 1
const FRAME_WALK2 = 2

var anim_frame: int = 0
var anim_timer: float = 0.0
var anim_speed: float = 0.12
var last_move_dir: Vector2 = Vector2.DOWN
var facing_right: bool = true
var near_portal: bool = false
var near_chest: Area2D = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var muzzle_point: Marker2D = $WeaponPivot/MuzzlePoint
@onready var dash_particles: CPUParticles2D = $DashParticles
@onready var hurtbox: Area2D = $Hurtbox
@onready var hit_flash_timer: Timer = $HitFlashTimer
@onready var portal_detector: Area2D = $PortalDetector
@onready var interact_detector: Area2D = $InteractDetector
@onready var flashlight_beam: Sprite2D = $FlashlightBeam

func _ready() -> void:
	apply_meta_upgrades()
	_generate_sprite_texture()
	hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	portal_detector.area_entered.connect(_on_portal_area_entered)
	portal_detector.area_exited.connect(_on_portal_area_exited)
	interact_detector.area_entered.connect(_on_interact_area_entered)
	interact_detector.area_exited.connect(_on_interact_area_exited)
	_give_starting_weapon()

func _give_starting_weapon() -> void:
	ammo_reserves["pistol"] = 30  # 先设储备，再 equip 才能自动装填
	var pistol_scene = load("res://scenes/weapons/pistol.tscn")
	if pistol_scene:
		var pistol = pistol_scene.instantiate()
		add_weapon(pistol)
		hotbar[1] = pistol
	hotbar[0] = "flashlight"
	_generate_flashlight_beam()
	_generate_flashlight_body()

func _generate_flashlight_beam() -> void:
	var w = 320
	var h = 160
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			var fx = float(x) / w
			var dy = abs(float(y) - h / 2.0) / (h / 2.0)
			var alpha = clamp(1.0 - fx, 0.0, 1.0) * clamp(1.0 - dy * 2.0, 0.0, 1.0)
			alpha = alpha * 0.35
			img.set_pixel(x, y, Color(1.0, 0.95, 0.7, alpha))
	var tex = ImageTexture.create_from_image(img)
	flashlight_beam.texture = tex
	flashlight_beam.centered = false
	flashlight_beam.offset = Vector2(0, -h / 2.0)
	flashlight_beam.visible = false

func _generate_flashlight_body() -> void:
	flashlight_body = Sprite2D.new()
	weapon_pivot.add_child(flashlight_body)

	var w = 20
	var h = 8
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	# body: dark gray cylinder
	for y in range(h):
		for x in range(w - 4):
			img.set_pixel(x, y, Color(0.25, 0.25, 0.30))
	# lens: lighter gray at right end
	for y in range(h):
		for x in range(w - 4, w - 1):
			img.set_pixel(x, y, Color(0.6, 0.6, 0.65))
	# glow: warm yellow at rightmost 1px
	for y in range(h):
		img.set_pixel(w - 1, y, Color(1.0, 0.95, 0.7, 0.8))

	var scale_factor = 2
	var big = Image.create(w * scale_factor, h * scale_factor, false, Image.FORMAT_RGBA8)
	for fy in range(h):
		for fx in range(w):
			var c = img.get_pixel(fx, fy)
			if c.a > 0:
				for dy in range(scale_factor):
					for dx in range(scale_factor):
						big.set_pixel(fx * scale_factor + dx, fy * scale_factor + dy, c)

	var tex = ImageTexture.create_from_image(big)
	flashlight_body.texture = tex
	flashlight_body.centered = true
	flashlight_body.position = Vector2(20, 0)
	flashlight_body.visible = false

func _generate_sprite_texture() -> void:
	var s = SPRITE_SIZE
	var img = Image.create(s * 3, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var skin = Color(0.86, 0.71, 0.59)
	var hair = Color(0.24, 0.16, 0.12)
	var jacket = Color(0.16, 0.20, 0.24)
	var pants = Color(0.20, 0.22, 0.20)
	var boots = Color(0.14, 0.12, 0.10)
	var gun_c = Color(0.35, 0.35, 0.40)
	var mask_c = Color(0.39, 0.39, 0.43)
	var eye = Color.WHITE
	var pupil = Color(0.08, 0.08, 0.08)

	for f in range(3):
		var ox = f * s
		# head (top-down: circle in upper portion)
		for y in range(2, 16):
			for x in range(14, 34):
				var dx = x - 24
				var dy = y - 9
				if dx * dx + dy * dy < 64:
					img.set_pixel(ox + x, y, skin)
		# hair (top of head)
		for y in range(1, 6):
			for x in range(14, 34):
				var dx = x - 24
				var dy = y - 4
				if dx * dx + dy * dy < 49:
					img.set_pixel(ox + x, y, hair)
		# eyes
		img.set_pixel(ox + 20, 7, eye)
		img.set_pixel(ox + 21, 7, pupil)
		img.set_pixel(ox + 26, 7, eye)
		img.set_pixel(ox + 27, 7, pupil)
		# mask
		for y in range(12, 16):
			for x in range(16, 32):
				img.set_pixel(ox + x, y, mask_c)
		# body (torso)
		for y in range(16, 32):
			for x in range(12, 36):
				var dx = x - 24
				var dy = y - 24
				if dx * dx * 0.7 + dy * dy * 0.3 < 100:
					img.set_pixel(ox + x, y, jacket)
		# pants
		for y in range(30, 40):
			for x in range(14, 34):
				img.set_pixel(ox + x, y, pants)
		# boots
		for y in range(40, 46):
			for x in range(14, 34):
				img.set_pixel(ox + x, y, boots)

		if f == FRAME_IDLE:
			# gun pointing down-right
			for y in range(18, 22):
				for x in range(34, 42):
					img.set_pixel(ox + x, y, gun_c)
		elif f == FRAME_WALK1:
			# gun slightly forward
			for y in range(17, 21):
				for x in range(34, 43):
					img.set_pixel(ox + x, y, gun_c)
			# left leg forward
			for y in range(40, 48):
				for x in range(12, 18):
					img.set_pixel(ox + x, y, boots)
		elif f == FRAME_WALK2:
			# gun slightly back
			for y in range(19, 23):
				for x in range(33, 41):
					img.set_pixel(ox + x, y, gun_c)
			# right leg forward
			for y in range(40, 48):
				for x in range(30, 36):
					img.set_pixel(ox + x, y, boots)

	var big = Image.create(s * 3 * SCALE, s * SCALE, false, Image.FORMAT_RGBA8)
	big.fill(Color(0, 0, 0, 0))
	for fy in range(s):
		for fx in range(s * 3):
			var c = img.get_pixel(fx, fy)
			if c.a > 0:
				for dy in range(SCALE):
					for dx in range(SCALE):
						big.set_pixel(fx * SCALE + dx, fy * SCALE + dy, c)

	var tex = ImageTexture.create_from_image(big)
	sprite.texture = tex
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, s * SCALE, s * SCALE)
	sprite.offset = Vector2(-s * SCALE / 2.0, -s * SCALE / 2.0)

func apply_meta_upgrades() -> void:
	max_health += MetaProgression.get_upgrade_value("max_health")
	health = max_health
	move_speed += MetaProgression.get_upgrade_value("move_speed")
	dash_cooldown -= MetaProgression.get_upgrade_value("dash_cooldown")
	dash_cooldown = max(dash_cooldown, 0.3)

func _process(delta: float) -> void:
	if is_dead or GameManager.current_state != GameManager.GameState.PLAYING:
		return
	anim_timer += delta
	if anim_timer >= anim_speed:
		anim_timer = 0.0
		anim_frame = (anim_frame + 1) % 2
	if flashlight_on:
		var mp = get_global_mouse_position()
		flashlight_beam.rotation = (mp - global_position).angle()
		flashlight_beam.global_position = global_position

func _physics_process(delta: float) -> void:
	if is_dead or GameManager.current_state != GameManager.GameState.PLAYING:
		return

	if is_dashing:
		_process_dash(delta)
		return

	dash_cooldown_timer = max(0.0, dash_cooldown_timer - delta)
	stamina = min(stamina + stamina_regen * delta, max_stamina)
	stamina_changed.emit(stamina, max_stamina)
	_handle_movement(delta)
	_handle_weapon_aim()
	_handle_actions()
	_update_flashlight()

func _handle_movement(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0 and input_dir != Vector2.ZERO and stamina >= dash_stamina_cost:
		_start_dash(input_dir)

	if input_dir != Vector2.ZERO:
		velocity = input_dir * move_speed
		last_move_dir = input_dir
		if input_dir.x > 0:
			facing_right = true
			sprite.scale.x = abs(sprite.scale.x)
		elif input_dir.x < 0:
			facing_right = false
			sprite.scale.x = -abs(sprite.scale.x)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * 10 * delta)

	_update_animation(input_dir)
	move_and_slide()

func _start_dash(dir: Vector2) -> void:
	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	stamina -= dash_stamina_cost
	stamina_changed.emit(stamina, max_stamina)
	velocity = dir * dash_speed
	dash_particles.emitting = true

func _process_dash(delta: float) -> void:
	dash_timer -= delta
	move_and_slide()
	if dash_timer <= 0.0:
		is_dashing = false
		velocity = Vector2.ZERO

func _handle_weapon_aim() -> void:
	var mouse_pos := get_global_mouse_position()
	weapon_pivot.look_at(mouse_pos)

func _handle_actions() -> void:
	if current_weapon:
		var should_attack := Input.is_action_pressed("shoot") if current_weapon.automatic else Input.is_action_just_pressed("shoot")
		if should_attack:
			var dir := (get_global_mouse_position() - muzzle_point.global_position).normalized()
			current_weapon.attack(muzzle_point.global_position, dir)

	if Input.is_action_just_pressed("reload") and current_weapon and current_weapon.weapon_kind == Weapon.WeaponKind.RANGED:
		current_weapon.start_reload()

	if Input.is_key_pressed(KEY_1): _select_hotbar(0)
	if Input.is_key_pressed(KEY_2): _select_hotbar(1)
	if Input.is_key_pressed(KEY_3): _select_hotbar(2)
	if Input.is_key_pressed(KEY_4): _select_hotbar(3)

	if Input.is_action_just_pressed("interact"):
		if near_chest:
			_open_chest()
		elif near_portal:
			_use_portal()
		else:
			_try_toggle_door()

func _update_animation(input_dir: Vector2) -> void:
	var fw = SPRITE_SIZE * SCALE
	var fh = SPRITE_SIZE * SCALE
	var frame_x = 0
	if input_dir != Vector2.ZERO:
		frame_x = (FRAME_WALK1 + anim_frame) * fw
	else:
		frame_x = FRAME_IDLE * fw
	sprite.region_rect = Rect2(frame_x, 0, fw, fh)

func _toggle_flashlight() -> void:
	flashlight_on = not flashlight_on
	flashlight_beam.visible = flashlight_on

func _update_flashlight() -> void:
	var fog = get_tree().get_first_node_in_group("fog")
	if not fog:
		return
	fog.clear_radius = 220.0 if (flashlight_on and has_flashlight) else 110.0

func _select_hotbar(idx: int) -> void:
	hotbar_selected = idx
	var item = hotbar[idx]
	if item is String and item == "flashlight":
		# 切到手电筒 → 卸下当前武器
		if current_weapon:
			current_weapon.unequip()
			current_weapon = null
			weapon_changed.emit(null)
	elif item is Weapon and item != current_weapon:
		equip_weapon(item)
	if flashlight_body:
		flashlight_body.visible = (hotbar_selected == 0)

func move_to_hotbar(backpack_idx: int) -> void:
	var wp_idx = backpack_idx - 1 if (hotbar[0] is String and hotbar[0] == "flashlight") else backpack_idx
	if wp_idx >= 0 and wp_idx < weapon_inventory.size():
		hotbar[hotbar_selected] = weapon_inventory[wp_idx]

func has_flashlight_in_hotbar() -> bool:
	for item in hotbar:
		if item is String and item == "flashlight":
			return true
	return false

func equip_weapon(weapon: Weapon) -> void:
	if current_weapon:
		current_weapon.unequip()
	current_weapon = weapon
	weapon.equip(self)
	weapon_changed.emit(weapon)

func add_weapon(weapon: Weapon) -> void:
	weapon_inventory.append(weapon)
	if weapon_inventory.size() == 1:
		equip_weapon(weapon)


func remove_weapon(weapon: Weapon) -> void:
	var idx := weapon_inventory.find(weapon)
	if idx == -1:
		return
	var was_equipped := weapon == current_weapon
	weapon_inventory.remove_at(idx)
	# 清理 hotbar 中的悬空引用
	for i in hotbar.size():
		if hotbar[i] == weapon:
			hotbar[i] = null
	if was_equipped:
		current_weapon = null
		# 尝试装备下一个武器
		for w in weapon_inventory:
			equip_weapon(w)
			break
	weapon.queue_free()


func drop_weapon() -> void:
	if current_weapon:
		remove_weapon(current_weapon)


## 弹药储备管理

func get_ammo_reserve(ammo_type: String) -> int:
	return ammo_reserves.get(ammo_type, 0)


func consume_ammo(ammo_type: String, amount: int) -> bool:
	var current: int = ammo_reserves.get(ammo_type, 0)
	if current < amount:
		return false
	ammo_reserves[ammo_type] = current - amount
	return true


func add_ammo(ammo_type: String, amount: int) -> void:
	ammo_reserves[ammo_type] = ammo_reserves.get(ammo_type, 0) + amount
	# 如果当前武器使用该弹药类型，刷新 HUD
	if current_weapon and current_weapon.ammo_type == ammo_type:
		RunManager.ammo_changed.emit(current_weapon.current_ammo, current_weapon.max_ammo)

func take_damage(amount: float) -> void:
	if is_dead or is_dashing or is_invincible:
		return
	health -= amount
	health_changed.emit(health, max_health)
	_flash_hit()
	if health <= 0:
		die()

func heal(amount: float) -> void:
	health = min(health + amount, max_health)
	health_changed.emit(health, max_health)

func _flash_hit() -> void:
	if sprite.material is ShaderMaterial:
		sprite.material.set_shader_parameter("flash_intensity", 1.0)
	hit_flash_timer.start()

func _on_hit_flash_timeout() -> void:
	if sprite.material is ShaderMaterial:
		sprite.material.set_shader_parameter("flash_intensity", 0.0)

func _on_hurtbox_body_entered(body: Node2D) -> void:
	if body is Enemy:
		take_damage(body.contact_damage)

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.get("damage") != null:
		take_damage(area.damage)
		area.queue_free()

func die() -> void:
	is_dead = true
	sprite.modulate = Color(1, 0.3, 0.3, 1)
	GameManager.game_over()

func _on_portal_area_entered(area: Area2D) -> void:
	near_portal = true

func _on_portal_area_exited(area: Area2D) -> void:
	near_portal = false

func _on_interact_area_entered(area: Area2D) -> void:
	if area.name == "Chest":
		near_chest = area

func _on_interact_area_exited(area: Area2D) -> void:
	if near_chest == area:
		near_chest = null

func _find_room_at(pos: Vector2) -> Room:
	var generator = get_parent()
	if generator and generator.has_method("_world_to_grid"):
		var gp = generator._world_to_grid(pos)
		var rm = generator.get("room_map") as Dictionary
		if rm and rm.has(gp):
			return rm[gp] as Room
	return null

func _try_toggle_door() -> void:
	var room = _find_room_at(global_position)
	if not room or not room.is_lockable_room:
		return
	var d = room.get_nearest_door_dir(global_position)
	if d >= 0:
		room.toggle_door_lock(d)

func _open_chest() -> void:
	if not near_chest:
		return
	var item = near_chest
	near_chest = null
	if current_weapon:
		current_weapon.current_ammo = current_weapon.max_ammo
		RunManager.ammo_changed.emit(current_weapon.current_ammo, current_weapon.max_ammo)
	health = max_health
	health_changed.emit(health, max_health)
	item.queue_free()

func _use_portal() -> void:
	RunManager.next_floor()
	var level_generator = get_parent()
	if level_generator and level_generator.has_method("generate_floor"):
		level_generator.generate_floor()
