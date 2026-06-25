extends Control

@onready var panel: Panel = $Panel
@onready var grid: GridContainer = $Panel/GridContainer
@onready var weapon_label: Label = $Panel/WeaponLabel

var slot_buttons: Array[Button] = []

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_slots()

func _create_slots() -> void:
	for i in range(8):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(80, 80)
		btn.text = ""
		btn.pressed.connect(_on_slot_pressed.bind(i))
		grid.add_child(btn)
		slot_buttons.append(btn)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		toggle()

func toggle() -> void:
	visible = not visible
	if visible:
		get_tree().paused = true
		_refresh()
	else:
		get_tree().paused = false

func _refresh() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var inv = player.weapon_inventory
	var cur = player.current_weapon

	for i in slot_buttons.size():
		if i < inv.size():
			var w = inv[i] as Weapon
			var txt = w.weapon_name + "\n%d/%d" % [w.current_ammo, w.max_ammo]
			if w == cur:
				txt = "[E] " + txt
			slot_buttons[i].text = txt
		else:
			slot_buttons[i].text = ""

func _on_slot_pressed(idx: int) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	if idx < player.weapon_inventory.size():
		player.equip_weapon(player.weapon_inventory[idx])
		_refresh()
