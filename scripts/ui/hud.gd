extends CanvasLayer

@onready var health_bar: ProgressBar = $VBoxContainer/HealthRow/HealthBar
@onready var sanity_bar: ProgressBar = $VBoxContainer/SanityRow/SanityBar
@onready var stamina_bar: ProgressBar = $VBoxContainer/StaminaRow/StaminaBar
@onready var ammo_label: Label = $VBoxContainer/AmmoLabel
@onready var floor_label: Label = $VBoxContainer/FloorLabel
@onready var weapon_label: Label = $VBoxContainer/WeaponLabel
@onready var minimap: Control = $Minimap

func _ready() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.health_changed.connect(_on_health_changed)
		player.stamina_changed.connect(_on_stamina_changed)
		player.ammo_changed.connect(_on_ammo_changed)
		player.weapon_changed.connect(_on_weapon_changed)

	RunManager.floor_changed.connect(_on_floor_changed)
	RunManager.sanity_changed.connect(_on_sanity_changed)

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
