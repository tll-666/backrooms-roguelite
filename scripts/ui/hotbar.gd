extends Control

var slot_buttons: Array[Button] = []

func _ready() -> void:
	for i in range(4):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(50, 50)
		btn.text = ""
		var style = StyleBoxFlat.new()
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.border_color = Color(0.7, 0.7, 0.7)
		style.bg_color = Color(0.15, 0.15, 0.15, 0.9)
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.pressed.connect(_on_slot_pressed.bind(i))
		add_child(btn)
		slot_buttons.append(btn)

func _process(_delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var hb = player.hotbar
	for i in slot_buttons.size():
		var txt = ""
		if hb[i] == "flashlight":
			txt = "手电"
		elif hb[i] is Weapon:
			txt = hb[i].weapon_name
		slot_buttons[i].text = txt
		slot_buttons[i].modulate = Color.WHITE if i == player.hotbar_selected else Color(0.4, 0.4, 0.4)

func _on_slot_pressed(idx: int) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	if idx == player.hotbar_selected:
		var item = player.hotbar[idx]
		if item == "flashlight":
			player._toggle_flashlight()
		elif item is Weapon and item == player.current_weapon:
			pass
	else:
		player.hotbar_selected = idx
		player._select_hotbar(idx)
