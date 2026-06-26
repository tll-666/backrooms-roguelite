extends CanvasLayer

@onready var health_bar: ProgressBar = $VBoxContainer/HealthRow/HealthBar
@onready var sanity_bar: ProgressBar = $VBoxContainer/SanityRow/SanityBar
@onready var stamina_bar: ProgressBar = $VBoxContainer/StaminaRow/StaminaBar
@onready var ammo_label: Label = $VBoxContainer/AmmoLabel
@onready var floor_label: Label = $VBoxContainer/FloorLabel
@onready var weapon_label: Label = $VBoxContainer/WeaponLabel
@onready var minimap: Control = $Minimap

var reload_bar: ProgressBar
var _tracked_weapon: Weapon = null

func _ready() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.health_changed.connect(_on_health_changed)
		player.stamina_changed.connect(_on_stamina_changed)
		player.weapon_changed.connect(_on_weapon_changed)
		# 弥补初始化竞态：Player._ready 先于 HUD._ready，首把武器 equip 信号已丢失
		if player.current_weapon:
			_on_weapon_changed(player.current_weapon)

	RunManager.floor_changed.connect(_on_floor_changed)
	RunManager.sanity_changed.connect(_on_sanity_changed)
	RunManager.ammo_changed.connect(_on_ammo_changed)

	# 创建换弹进度条（动态创建，不编辑 tscn）
	reload_bar = ProgressBar.new()
	reload_bar.name = "ReloadBar"
	reload_bar.custom_minimum_size = Vector2(180, 8)
	reload_bar.max_value = 1.0
	reload_bar.value = 0.0
	reload_bar.show_percentage = false
	reload_bar.visible = false
	reload_bar.add_theme_color_override("font_color", Color(0.9, 0.85, 0.3))
	reload_bar.add_theme_stylebox_override("fill", _make_reload_style())
	$VBoxContainer.add_child(reload_bar)
	# 移到 AmmoLabel 之后
	var ammo_idx = $VBoxContainer/AmmoLabel.get_index()
	$VBoxContainer.move_child(reload_bar, ammo_idx + 1)

func _on_health_changed(current: float, max_hp: float) -> void:
	health_bar.max_value = max_hp
	health_bar.value = current

func _on_sanity_changed(current: float) -> void:
	sanity_bar.value = current

func _on_stamina_changed(current: float, max_st: float) -> void:
	stamina_bar.max_value = max_st
	stamina_bar.value = current

func _on_ammo_changed(current: int, max_ammo: int) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.current_weapon and player.has_method("get_ammo_reserve"):
		var reserve = player.get_ammo_reserve(player.current_weapon.ammo_type)
		ammo_label.text = "%d / %d  备%d" % [current, max_ammo, reserve]
	else:
		ammo_label.text = "%d / %d" % [current, max_ammo]

func _on_floor_changed(floor: int) -> void:
	floor_label.text = "楼层 %d" % floor

func _on_weapon_changed(weapon: Weapon) -> void:
	if weapon:
		weapon_label.text = weapon.weapon_name
		_bind_reload_bar(weapon)
	else:
		weapon_label.text = ""
		_unbind_reload_bar()

func _make_reload_style() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.85, 0.7, 0.2)
	s.corner_radius_top_left = 3
	s.corner_radius_top_right = 3
	s.corner_radius_bottom_left = 3
	s.corner_radius_bottom_right = 3
	return s

func _bind_reload_bar(weapon: Weapon) -> void:
	_unbind_reload_bar()
	_tracked_weapon = weapon
	if weapon.has_signal("reload_started") and weapon.has_signal("reload_progress"):
		weapon.reload_started.connect(_on_reload_started)
		weapon.reload_progress.connect(_on_reload_progress)

func _unbind_reload_bar() -> void:
	if _tracked_weapon and is_instance_valid(_tracked_weapon):
		if _tracked_weapon.reload_started.is_connected(_on_reload_started):
			_tracked_weapon.reload_started.disconnect(_on_reload_started)
		if _tracked_weapon.reload_progress.is_connected(_on_reload_progress):
			_tracked_weapon.reload_progress.disconnect(_on_reload_progress)
	_tracked_weapon = null
	reload_bar.visible = false

func _on_reload_started(duration: float) -> void:
	reload_bar.visible = true
	reload_bar.value = 0.0

func _on_reload_progress(progress: float) -> void:
	reload_bar.value = progress
	if progress >= 1.0:
		reload_bar.visible = false
