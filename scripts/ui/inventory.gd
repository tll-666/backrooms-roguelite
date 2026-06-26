extends Control

@onready var panel: Panel = $Panel
@onready var grid: GridContainer = $Panel/GridContainer
@onready var weapon_label: Label = $Panel/WeaponLabel

var slot_buttons: Array[Button] = []

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_slots()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		toggle()

func _create_slots() -> void:
	for i in range(8):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(80, 60)
		btn.text = ""
		btn.pressed.connect(_on_slot_pressed.bind(i))
		grid.add_child(btn)
		slot_buttons.append(btn)

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
	var sel = player.hotbar_selected

	var idx = 0
	if player.has_flashlight:
		var in_hotbar = player.has_flashlight_in_hotbar()
		slot_buttons[idx].text = "手电筒\n" + ("[开]" if player.flashlight_on else "[关]") + (" (已装备)" if in_hotbar else "")
		idx += 1

	for i in inv.size():
		if idx >= slot_buttons.size():
			break
		var w = inv[i] as Weapon
		var txt = w.weapon_name + "\n%d/%d" % [w.current_ammo, w.max_ammo]
		if w == cur:
			txt = "[装备中] " + txt
		slot_buttons[idx].text = txt
		idx += 1

	# 显示弹药储备
	if idx < slot_buttons.size() and player.has_method("get_ammo_reserve"):
		var reserves: Dictionary = player.ammo_reserves
		if not reserves.is_empty():
			var ammo_lines: Array[String] = []
			for ammo_type in reserves:
				ammo_lines.append("%s: %d" % [ammo_type, reserves[ammo_type]])
			slot_buttons[idx].text = "弹药\n" + "\n".join(ammo_lines)
			idx += 1

	for i in range(idx, slot_buttons.size()):
		slot_buttons[i].text = ""

	weapon_label.text = "选中格子 %d — 点击物品装入物品栏" % (sel + 1)

func _on_slot_pressed(idx: int) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	if idx == 0 and player.has_flashlight:
		player.hotbar[player.hotbar_selected] = "flashlight"
		_refresh()
		return

	player.move_to_hotbar(idx)
	_refresh()
