extends Control

const ICON_SIZE = 32

var slot_buttons: Array[Button] = []
var _icons: Dictionary = {}

func _ready() -> void:
	_generate_icons()
	for i in range(4):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(50, 50)
		btn.text = ""
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.expand_icon = true
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

func _generate_icons() -> void:
	# 手枪 24x12 → 2x → 缩减到 32x32 居中
	var p_img = Image.create(24, 12, false, Image.FORMAT_RGBA8)
	p_img.fill(Color(0, 0, 0, 0))
	var metal = Color(0.35, 0.35, 0.40)
	var dark = Color(0.20, 0.22, 0.24)
	var hl = Color(0.5, 0.5, 0.55)
	for x in range(8, 23):
		for y in range(4, 7):
			p_img.set_pixel(x, y, metal)
	for x in range(6, 19):
		for y in range(5, 10):
			p_img.set_pixel(x, y, metal)
	for x in range(4, 9):
		for y in range(8, 12):
			p_img.set_pixel(x, y, dark)
	p_img.set_pixel(22, 3, hl)
	p_img.set_pixel(23, 3, hl)
	# 2x upscale
	var p_big = Image.create(48, 24, false, Image.FORMAT_RGBA8)
	p_big.fill(Color(0,0,0,0))
	for y in range(12):
		for x in range(24):
			var c = p_img.get_pixel(x, y)
			if c.a > 0:
				for dy in range(2):
					for dx in range(2):
						p_big.set_pixel(x*2+dx, y*2+dy, c)
	# Center into 32x32
	var p_dst = Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	p_dst.fill(Color(0,0,0,0))
	var ox = (ICON_SIZE - 48) / 2
	var oy = (ICON_SIZE - 24) / 2
	for y in range(24):
		for x in range(48):
			var c = p_big.get_pixel(x, y)
			if c.a > 0:
				p_dst.set_pixel(ox + x, oy + y, c)
	_icons["pistol"] = ImageTexture.create_from_image(p_dst)

	# 匕首 16x16 → 2x → 32x32
	var d_img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	d_img.fill(Color(0,0,0,0))
	var blade = Color(0.85, 0.85, 0.90)
	var edge = Color(0.95, 0.95, 0.98)
	var handle = Color(0.20, 0.14, 0.10)
	for y in range(4, 11):
		var lx = 8 + int(4.0 * (y - 4) / 6.0)
		for x in range(lx, 13):
			d_img.set_pixel(x, y, blade if x != lx and x != 12 else edge)
	for x in range(7, 14):
		d_img.set_pixel(x, 10, handle)
	for x in range(9, 12):
		for y in range(11, 15):
			d_img.set_pixel(x, y, handle)
	var d_big = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	d_big.fill(Color(0,0,0,0))
	for y in range(16):
		for x in range(16):
			var c = d_img.get_pixel(x, y)
			if c.a > 0:
				for dy in range(2):
					for dx in range(2):
						d_big.set_pixel(x*2+dx, y*2+dy, c)
	_icons["dagger"] = ImageTexture.create_from_image(d_big)

	# 定身枪 24x12 → 同上手枪但加青色线圈
	var s_img = Image.create(24, 12, false, Image.FORMAT_RGBA8)
	s_img.fill(Color(0,0,0,0))
	var cyan = Color(0.4, 0.8, 0.95)
	var glow = Color(0.6, 0.9, 1.0)
	for x in range(8, 23):
		for y in range(4, 7):
			s_img.set_pixel(x, y, metal)
	for x in range(6, 19):
		for y in range(5, 10):
			s_img.set_pixel(x, y, metal)
	for x in range(4, 9):
		for y in range(8, 12):
			s_img.set_pixel(x, y, dark)
	# 线圈竖纹
	for i in range(3):
		var cx = 11 + i * 3
		for y in range(3, 6):
			s_img.set_pixel(cx, y, cyan)
	s_img.set_pixel(22, 3, glow)
	s_img.set_pixel(23, 3, glow)
	var s_big = Image.create(48, 24, false, Image.FORMAT_RGBA8)
	s_big.fill(Color(0,0,0,0))
	for y in range(12):
		for x in range(24):
			var c = s_img.get_pixel(x, y)
			if c.a > 0:
				for dy in range(2):
					for dx in range(2):
						s_big.set_pixel(x*2+dx, y*2+dy, c)
	var s_dst = Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	s_dst.fill(Color(0,0,0,0))
	for y in range(24):
		for x in range(48):
			var c = s_big.get_pixel(x, y)
			if c.a > 0:
				s_dst.set_pixel(ox + x, oy + y, c)
	_icons["stun_gun"] = ImageTexture.create_from_image(s_dst)

	# 手电筒 20x8 2x → 40x16 → center 32x32
	var f_img = Image.create(20, 8, false, Image.FORMAT_RGBA8)
	f_img.fill(Color(0,0,0,0))
	var body_c = Color(0.25, 0.25, 0.30)
	var lens_c = Color(0.6, 0.6, 0.65)
	var warm = Color(1.0, 0.95, 0.7)
	for x in range(3, 18):
		for y in range(2, 6):
			f_img.set_pixel(x, y, body_c)
	for x in range(18, 20):
		for y in range(1, 7):
			f_img.set_pixel(x, y, lens_c)
	for y in range(2, 6):
		f_img.set_pixel(19, y, warm)
	var f_big = Image.create(40, 16, false, Image.FORMAT_RGBA8)
	f_big.fill(Color(0,0,0,0))
	for y in range(8):
		for x in range(20):
			var c = f_img.get_pixel(x, y)
			if c.a > 0:
				for dy in range(2):
					for dx in range(2):
						f_big.set_pixel(x*2+dx, y*2+dy, c)
	var f_dst = Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	f_dst.fill(Color(0,0,0,0))
	var fox = (ICON_SIZE - 40) / 2
	var foy = (ICON_SIZE - 16) / 2
	for y in range(16):
		for x in range(40):
			var c = f_big.get_pixel(x, y)
			if c.a > 0:
				f_dst.set_pixel(fox + x, foy + y, c)
	_icons["flashlight"] = ImageTexture.create_from_image(f_dst)

	# 手电筒开启（暖光版）
	var f_on_img = Image.create(20, 8, false, Image.FORMAT_RGBA8)
	f_on_img.fill(Color(0,0,0,0))
	for x in range(3, 18):
		for y in range(2, 6):
			f_on_img.set_pixel(x, y, body_c)
	for x in range(18, 20):
		for y in range(1, 7):
			f_on_img.set_pixel(x, y, lens_c)
	for y in range(1, 7):
		f_on_img.set_pixel(19, y, warm)
	# 光束 hint
	f_on_img.set_pixel(20, 3, Color(1.0, 0.9, 0.5, 0.7))
	f_on_img.set_pixel(21, 3, Color(1.0, 0.9, 0.5, 0.5))
	f_on_img.set_pixel(20, 4, Color(1.0, 0.9, 0.5, 0.7))
	f_on_img.set_pixel(21, 4, Color(1.0, 0.9, 0.5, 0.5))
	var f_on_big = Image.create(44, 16, false, Image.FORMAT_RGBA8)
	f_on_big.fill(Color(0,0,0,0))
	for y in range(8):
		for x in range(22):
			var c = f_on_img.get_pixel(x, y)
			if c.a > 0:
				for dy in range(2):
					for dx in range(2):
						f_on_big.set_pixel(x*2+dx, y*2+dy, c)
	var f_on_dst = Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	f_on_dst.fill(Color(0,0,0,0))
	var fon_ox = (ICON_SIZE - 44) / 2
	var fon_oy = (ICON_SIZE - 16) / 2
	for y in range(16):
		for x in range(44):
			var c = f_on_big.get_pixel(x, y)
			if c.a > 0:
				f_on_dst.set_pixel(fon_ox + x, fon_oy + y, c)
	_icons["flashlight_on"] = ImageTexture.create_from_image(f_on_dst)


func _process(_delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var hb = player.hotbar
	for i in slot_buttons.size():
		var item = hb[i]
		if item is String and item == "flashlight":
			var key = "flashlight_on" if player.flashlight_on else "flashlight"
			slot_buttons[i].icon = _icons.get(key)
			slot_buttons[i].tooltip_text = "手电筒" + (" [开]" if player.flashlight_on else " [关]")
		elif item is Weapon:
			var wname = item.weapon_name
			if wname == "匕首":
				slot_buttons[i].icon = _icons.get("dagger")
			elif wname == "定身枪":
				slot_buttons[i].icon = _icons.get("stun_gun")
			else:
				slot_buttons[i].icon = _icons.get("pistol")
			slot_buttons[i].tooltip_text = "%s (%d/%d)" % [wname, item.current_ammo, item.max_ammo]
		else:
			slot_buttons[i].icon = null
			slot_buttons[i].tooltip_text = ""
		slot_buttons[i].modulate = Color.WHITE if i == player.hotbar_selected else Color(0.4, 0.4, 0.4)


func _on_slot_pressed(idx: int) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	if idx == player.hotbar_selected:
		var item = player.hotbar[idx]
		if item is String and item == "flashlight":
			player._toggle_flashlight()
		elif item is Weapon and item == player.current_weapon:
			pass
	else:
		player.hotbar_selected = idx
		player._select_hotbar(idx)
