extends Node2D
class_name Weapon

## 武器种类：远程射击 或 近战挥砍
enum WeaponKind { RANGED, MELEE }

@export var weapon_name: String = "Pistol"
@export var weapon_kind: WeaponKind = WeaponKind.RANGED
# --- 远程属性 ---
@export var damage: float = 15.0
@export var fire_rate: float = 0.3
@export var max_ammo: int = 12
@export var reload_time: float = 1.5
@export var bullet_speed: float = 800.0
@export var spread_angle: float = 3.0
@export var bullets_per_shot: int = 1
@export var automatic: bool = false
@export var bullet_scene: PackedScene
# --- 近战属性 ---
@export var melee_range: float = 60.0
@export var melee_angle: float = 60.0
@export var melee_damage: float = 25.0
# --- 状态效果（由子弹/近战击中时施加） ---
@export var status_effect: String = ""
@export var effect_duration: float = 0.0
# --- 弹药类型（用于从玩家储备中拉取弹药） ---
@export var ammo_type: String = "pistol"

var current_ammo: int
var fire_timer: float = 0.0
var is_reloading: bool = false
var reload_timer: float = 0.0
var owner_player: Player = null

signal reload_started(effective_duration: float)
signal reload_progress(progress: float)
var reload_duration: float = 0.0

func _ready() -> void:
	# current_ammo 初始为 0，equip() 时从玩家储备自动装载
	_generate_sprite()


func _process(delta: float) -> void:
	fire_timer = max(0.0, fire_timer - delta)
	if is_reloading:
		reload_timer -= delta
		var progress: float = clampf(1.0 - reload_timer / reload_duration, 0.0, 1.0)
		reload_progress.emit(progress)
		if reload_timer <= 0.0:
			_finish_reload()


## 被玩家装备。确保 Weapon 进入场景树、挂在 WeaponPivot 下、visible 且 process 激活。
func equip(player: Player) -> void:
	owner_player = player
	var pivot := player.get_node("WeaponPivot")
	if not is_inside_tree():
		pivot.add_child(self)
	elif get_parent() != pivot:
		reparent(pivot)
	position = Vector2(20, 0)
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	# 首次装备时从玩家储备自动装载弹药
	if current_ammo <= 0 and owner_player.has_method("get_ammo_reserve"):
		_reload_from_reserve()
	RunManager.ammo_changed.emit(current_ammo, max_ammo)


## 卸下武器：隐藏并停止 processing，但保留在场景树中避免重复 _ready。
func unequip() -> void:
	owner_player = null
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED


## 主攻击入口，根据 weapon_kind 派发到 RANGED 或 MELEE。
func attack(origin: Vector2, direction: Vector2) -> bool:
	if weapon_kind == WeaponKind.MELEE:
		return _try_melee(origin, direction)
	return _try_shoot(origin, direction)


# --- 近战逻辑 ------------------------------------------------------------

func _try_melee(origin: Vector2, direction: Vector2) -> bool:
	if fire_timer > 0.0:
		return false
	fire_timer = fire_rate

	if weapon_kind == WeaponKind.MELEE:
		_spawn_melee_slash(origin, direction)

	if not owner_player:
		return false

	var enemies := owner_player.get_tree().get_nodes_in_group("enemy")
	var hit_any := false
	var half_cone := deg_to_rad(melee_angle / 2.0)

	for enemy in enemies:
		var e := enemy as Enemy
		if not e or e.is_dead:
			continue
		var to_enemy := e.global_position - origin
		if to_enemy.length() > melee_range:
			continue
		if abs(direction.angle_to(to_enemy)) > half_cone:
			continue
		e.take_damage(melee_damage)
		if status_effect != "" and e.has_method("apply_status"):
			e.apply_status(status_effect, effect_duration)
		hit_any = true

	return hit_any


# --- 远程逻辑 ------------------------------------------------------------

func _try_shoot(origin: Vector2, direction: Vector2) -> bool:
	if is_reloading or fire_timer > 0.0 or current_ammo <= 0:
		if current_ammo <= 0 and not is_reloading:
			start_reload()
		return false

	fire_timer = fire_rate
	current_ammo -= 1

	for i in bullets_per_shot:
		var spread := randf_range(-spread_angle, spread_angle)
		var bullet_dir := direction.rotated(deg_to_rad(spread))
		_spawn_bullet(origin, bullet_dir)

	RunManager.ammo_changed.emit(current_ammo, max_ammo)
	return true


func _spawn_bullet(origin: Vector2, direction: Vector2) -> void:
	if not bullet_scene:
		return
	var bullet := bullet_scene.instantiate() as Bullet
	owner_player.get_parent().add_child(bullet)
	bullet.global_position = origin
	bullet.direction = direction
	bullet.speed = bullet_speed
	bullet.damage = damage + MetaProgression.get_upgrade_value("damage")
	if status_effect != "":
		bullet.status_effect = status_effect
		bullet.effect_duration = effect_duration


func start_reload() -> void:
	if is_reloading or current_ammo >= max_ammo:
		return
	# 检查玩家弹药储备
	if owner_player and owner_player.has_method("get_ammo_reserve"):
		if owner_player.get_ammo_reserve(ammo_type) <= 0:
			return  # 无储备弹药，无法装填
	is_reloading = true
	reload_duration = reload_time - MetaProgression.get_upgrade_value("reload_speed")
	reload_timer = reload_duration
	reload_started.emit(reload_duration)


func _finish_reload() -> void:
	is_reloading = false
	reload_progress.emit(1.0)
	_reload_from_reserve()
	RunManager.ammo_changed.emit(current_ammo, max_ammo)


func _reload_from_reserve() -> void:
	if owner_player and owner_player.has_method("get_ammo_reserve") and owner_player.has_method("consume_ammo"):
		var reserve: int = owner_player.get_ammo_reserve(ammo_type)
		var to_load: int = min(max_ammo, reserve)
		if to_load > 0:
			owner_player.consume_ammo(ammo_type, to_load)
			current_ammo = to_load


func _generate_sprite() -> void:
	var sprite_node := get_node_or_null("Sprite2D") as Sprite2D
	if not sprite_node:
		return
	var img: Image
	if weapon_name == "匕首":
		img = _draw_dagger_pixel(16, 16)
	elif weapon_name == "定身枪":
		img = _draw_stun_gun_pixel(24, 12)
	else:
		img = _draw_pistol_pixel(24, 12)
	var w := img.get_width()
	var h := img.get_height()
	var big := Image.create(w * 2, h * 2, false, Image.FORMAT_RGBA8)
	big.fill(Color(0, 0, 0, 0))
	for y in range(h):
		for x in range(w):
			var c := img.get_pixel(x, y)
			if c.a > 0:
				for dy in range(2):
					for dx in range(2):
						big.set_pixel(x * 2 + dx, y * 2 + dy, c)
	var tex := ImageTexture.create_from_image(big)
	sprite_node.texture = tex


func _draw_pistol_pixel(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var metal := Color(0.35, 0.35, 0.40)
	var dark := Color(0.20, 0.22, 0.24)
	var highlight := Color(0.5, 0.5, 0.55)
	# 枪管 x(8-22) y(4-6)
	for x in range(8, 23):
		for y in range(4, 7):
			img.set_pixel(x, y, metal)
	# 枪身 x(6-18) y(5-9)
	for x in range(6, 19):
		for y in range(5, 10):
			img.set_pixel(x, y, metal)
	# 握把 x(4-8) y(8-11)
	for x in range(4, 9):
		for y in range(8, 12):
			img.set_pixel(x, y, dark)
	# 准星
	img.set_pixel(22, 3, highlight)
	img.set_pixel(23, 3, highlight)
	return img


func _draw_dagger_pixel(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var blade := Color(0.85, 0.85, 0.90)
	var handle := Color(0.20, 0.14, 0.10)
	var edge := Color(0.95, 0.95, 0.98)
	# 刀刃三角形：从 (8,4) 到 (12,10)，顶点 (8,4)，底边在 x=12
	for y in range(4, 11):
		var left_x: int = 8 + int(4.0 * (y - 4) / 6.0)
		for x in range(left_x, 13):
			if x == left_x or y == 4 or x == 12:
				img.set_pixel(x, y, edge)
			else:
				img.set_pixel(x, y, blade)
	# 护手 x(7-13) y(10)
	for x in range(7, 14):
		img.set_pixel(x, 10, handle)
	# 握柄 x(9-11) y(11-14)
	for x in range(9, 12):
		for y in range(11, 15):
			img.set_pixel(x, y, handle)
	return img


func _draw_stun_gun_pixel(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var metal := Color(0.35, 0.35, 0.40)
	var dark := Color(0.20, 0.22, 0.24)
	var cyan := Color(0.4, 0.8, 0.95)
	var glow := Color(0.6, 0.9, 1.0)
	# 枪管 x(8-22) y(4-6)
	for x in range(8, 23):
		for y in range(4, 7):
			img.set_pixel(x, y, metal)
	# 枪身 x(6-18) y(5-9)
	for x in range(6, 19):
		for y in range(5, 10):
			img.set_pixel(x, y, metal)
	# 握把 x(4-8) y(8-11)
	for x in range(4, 9):
		for y in range(8, 12):
			img.set_pixel(x, y, dark)
	# 线圈竖纹 x(11,14,17) y(2-6)
	for coil_x in [11, 14, 17]:
		for y in range(2, 7):
			img.set_pixel(coil_x, y, cyan)
	# 枪口发光 x(20-23) y(3-6)
	for x in range(20, 24):
		for y in range(3, 7):
			img.set_pixel(x, y, glow)
	return img


func _spawn_melee_slash(origin: Vector2, direction: Vector2) -> void:
	if not owner_player:
		return
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := 0
	var cy := s / 2
	var half_angle_rad := deg_to_rad(melee_angle / 2.0)
	for y in range(s):
		for x in range(s):
			var dx := x - cx
			var dy := y - cy
			var dist := sqrt(dx * dx + dy * dy)
			if dist < 8 or dist > s:
				continue
			var angle := atan2(dy, dx)
			if abs(angle) > half_angle_rad:
				continue
			var alpha := (1.0 - dist / s) * (1.0 - abs(angle) / half_angle_rad)
			alpha = alpha * 0.7
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	var tex := ImageTexture.create_from_image(img)
	var slash_sprite := Sprite2D.new()
	slash_sprite.texture = tex
	slash_sprite.centered = true
	slash_sprite.global_position = origin
	slash_sprite.rotation = direction.angle()
	slash_sprite.z_index = 20
	owner_player.get_parent().add_child(slash_sprite)
	var tween := slash_sprite.create_tween()
	tween.tween_property(slash_sprite, "modulate:a", 0.0, 0.18).set_ease(Tween.EASE_OUT)
	tween.tween_callback(slash_sprite.queue_free)
