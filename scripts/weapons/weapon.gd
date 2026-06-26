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

func _ready() -> void:
	# current_ammo 初始为 0，equip() 时从玩家储备自动装载
	pass


func _process(delta: float) -> void:
	fire_timer = max(0.0, fire_timer - delta)
	if is_reloading:
		reload_timer -= delta
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
	reload_timer = reload_time - MetaProgression.get_upgrade_value("reload_speed")


func _finish_reload() -> void:
	is_reloading = false
	_reload_from_reserve()
	RunManager.ammo_changed.emit(current_ammo, max_ammo)


func _reload_from_reserve() -> void:
	if owner_player and owner_player.has_method("get_ammo_reserve") and owner_player.has_method("consume_ammo"):
		var reserve: int = owner_player.get_ammo_reserve(ammo_type)
		var to_load: int = min(max_ammo, reserve)
		if to_load > 0:
			owner_player.consume_ammo(ammo_type, to_load)
			current_ammo = to_load
