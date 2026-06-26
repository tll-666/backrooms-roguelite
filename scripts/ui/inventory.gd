extends Control

# ============================================================
# Minecraft-style Inventory: 9x3 main grid + 9-slot hotbar
# ============================================================

const SLOT_SIZE := 44
const ICON_SIZE := 32
const MAIN_COLS := 9
const MAIN_ROWS := 3
const HOTBAR_COLS := 9

# --- StyleBox styles ---
var slot_normal_style: StyleBoxFlat
var slot_hover_style: StyleBoxFlat
var slot_selected_style: StyleBoxFlat

# --- UI nodes ---
var panel: Panel
var main_grid: GridContainer
var hotbar_grid: GridContainer
var title_label: Label

# --- Slot arrays ---
var main_slots: Array[Button] = []
var hotbar_slots: Array[Button] = []

# --- Tooltip ---
var tooltip_panel: Panel
var tooltip_label: RichTextLabel

# --- Detail panel ---
var detail_overlay: ColorRect
var detail_panel: Panel
var detail_icon: TextureRect
var detail_name_label: Label
var detail_info_label: RichTextLabel
var detail_equip_btn: Button
var detail_unequip_btn: Button
var detail_hotbar_btn: Button
var detail_discard_btn: Button
var detail_close_btn: Button
var detail_item: Variant = null  # Weapon or Dictionary for current detail target

# --- Icon cache ---
var _icon_cache: Dictionary = {}

# --- Internal state ---
var _tooltip_slot: Button = null
var _mouse_over_slot: bool = false


# ============================================================
# Lifecycle
# ============================================================

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	_build_styles()
	_build_icons()
	_destroy_old_children()
	_build_ui()
	_build_tooltip()
	_build_detail_panel()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		toggle()


# ============================================================
# Styles
# ============================================================

func _build_styles() -> void:
	slot_normal_style = StyleBoxFlat.new()
	slot_normal_style.bg_color = Color(0.18, 0.18, 0.20, 0.95)
	slot_normal_style.border_width_left = 2
	slot_normal_style.border_width_right = 2
	slot_normal_style.border_width_top = 2
	slot_normal_style.border_width_bottom = 2
	slot_normal_style.border_color = Color(0.5, 0.5, 0.5)
	slot_normal_style.corner_radius_top_left = 2
	slot_normal_style.corner_radius_top_right = 2
	slot_normal_style.corner_radius_bottom_left = 2
	slot_normal_style.corner_radius_bottom_right = 2

	slot_hover_style = StyleBoxFlat.new()
	slot_hover_style.bg_color = Color(0.25, 0.25, 0.28, 0.95)
	slot_hover_style.border_width_left = 2
	slot_hover_style.border_width_right = 2
	slot_hover_style.border_width_top = 2
	slot_hover_style.border_width_bottom = 2
	slot_hover_style.border_color = Color(0.8, 0.8, 0.8)
	slot_hover_style.corner_radius_top_left = 2
	slot_hover_style.corner_radius_top_right = 2
	slot_hover_style.corner_radius_bottom_left = 2
	slot_hover_style.corner_radius_bottom_right = 2

	slot_selected_style = StyleBoxFlat.new()
	slot_selected_style.bg_color = Color(0.18, 0.18, 0.20, 0.95)
	slot_selected_style.border_width_left = 2
	slot_selected_style.border_width_right = 2
	slot_selected_style.border_width_top = 2
	slot_selected_style.border_width_bottom = 2
	slot_selected_style.border_color = Color(0.9, 0.85, 0.3)
	slot_selected_style.corner_radius_top_left = 2
	slot_selected_style.corner_radius_top_right = 2
	slot_selected_style.corner_radius_bottom_left = 2
	slot_selected_style.corner_radius_bottom_right = 2


# ============================================================
# Toggle
# ============================================================

func toggle() -> void:
	visible = not visible
	if visible:
		get_tree().paused = true
		_refresh()
		_close_detail()
	else:
		get_tree().paused = false
		_close_detail()


# ============================================================
# Cleanup old tscn children
# ============================================================

func _destroy_old_children() -> void:
	var p = $Panel if has_node("Panel") else null
	if not p:
		return
	for child in p.get_children():
		child.queue_free()


# ============================================================
# Build UI
# ============================================================

func _build_ui() -> void:
	panel = $Panel if has_node("Panel") else null
	if not panel:
		panel = Panel.new()
		panel.name = "Panel"
		add_child(panel)

	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(520, 420)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	vbox.add_child(margin)

	var content_vbox := VBoxContainer.new()
	content_vbox.name = "ContentVBox"
	content_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(content_vbox)

	# --- Title ---
	var title_hbox := HBoxContainer.new()
	title_hbox.name = "TitleHBox"
	content_vbox.add_child(title_hbox)

	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "背包 [B]"
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hbox.add_child(title_label)

	# --- Separator ---
	var sep1 := HSeparator.new()
	sep1.name = "Separator1"
	content_vbox.add_child(sep1)

	# --- Main Grid (9x3) ---
	main_grid = GridContainer.new()
	main_grid.name = "MainGrid"
	main_grid.columns = MAIN_COLS
	main_grid.add_theme_constant_override("h_separation", 2)
	main_grid.add_theme_constant_override("v_separation", 2)
	content_vbox.add_child(main_grid)

	for i in range(MAIN_COLS * MAIN_ROWS):
		var slot := _create_slot("main", i)
		main_grid.add_child(slot)
		main_slots.append(slot)

	# --- Separator ---
	var sep2 := HSeparator.new()
	sep2.name = "Separator2"
	content_vbox.add_child(sep2)

	# --- Hotbar Row (9 slots) ---
	hotbar_grid = GridContainer.new()
	hotbar_grid.name = "HotbarGrid"
	hotbar_grid.columns = HOTBAR_COLS
	hotbar_grid.add_theme_constant_override("h_separation", 2)
	hotbar_grid.add_theme_constant_override("v_separation", 2)
	content_vbox.add_child(hotbar_grid)

	for i in range(HOTBAR_COLS):
		var slot := _create_slot("hotbar", i)
		hotbar_grid.add_child(slot)
		hotbar_slots.append(slot)

	# --- Close button ---
	var close_btn := Button.new()
	close_btn.name = "CloseBtn"
	close_btn.text = "关闭 [B]"
	close_btn.custom_minimum_size = Vector2(0, 32)
	close_btn.pressed.connect(toggle)
	content_vbox.add_child(close_btn)


func _create_slot(slot_type: String, slot_index: int) -> Button:
	var btn := Button.new()
	btn.name = "%s_Slot%d" % [slot_type, slot_index]
	btn.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	btn.text = ""
	btn.expand_icon = false
	btn.set_meta("slot_type", slot_type)
	btn.set_meta("slot_index", slot_index)
	btn.set_meta("item", null)
	btn.set_meta("item_kind", "")  # "flashlight", "weapon", "ammo", ""

	btn.add_theme_stylebox_override("normal", slot_normal_style)
	btn.add_theme_stylebox_override("hover", slot_hover_style)
	btn.add_theme_stylebox_override("pressed", slot_normal_style)
	btn.add_theme_stylebox_override("focus", slot_normal_style)

	# Icon (TextureRect overlaid)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.position = Vector2((SLOT_SIZE - ICON_SIZE) / 2.0, (SLOT_SIZE - ICON_SIZE) / 2.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)

	# Count label (bottom-right)
	var count_label := Label.new()
	count_label.name = "Count"
	count_label.position = Vector2(SLOT_SIZE - 22, SLOT_SIZE - 16)
	count_label.size = Vector2(20, 14)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count_label.add_theme_font_size_override("font_size", 10)
	count_label.add_theme_color_override("font_color", Color.WHITE)
	count_label.add_theme_color_override("font_outline_color", Color.BLACK)
	count_label.add_theme_constant_override("outline_size", 2)
	count_label.text = ""
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(count_label)

	# Signals
	btn.pressed.connect(_on_slot_pressed.bind(btn))
	btn.mouse_entered.connect(_on_slot_mouse_entered.bind(btn))
	btn.mouse_exited.connect(_on_slot_mouse_exited.bind(btn))

	return btn


# ============================================================
# Procedural Icons
# ============================================================

func _build_icons() -> void:
	# Pistol icon: gray silhouette, 36x18
	var pistol_img := Image.create(36, 18, false, Image.FORMAT_RGBA8)
	pistol_img.fill(Color(0, 0, 0, 0))
	_pixels_rect(pistol_img, 1, 1, 30, 4, Color(0.45, 0.45, 0.48))
	_pixels_rect(pistol_img, 22, 1, 4, 14, Color(0.45, 0.45, 0.48))
	_pixels_rect(pistol_img, 26, 10, 9, 4, Color(0.35, 0.35, 0.38))
	_pixels_rect(pistol_img, 12, 4, 6, 10, Color(0.35, 0.35, 0.38))
	_icon_cache["pistol"] = _resize_icon_to_cache(pistol_img)

	# Dagger icon: 16x16
	var dagger_img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	dagger_img.fill(Color(0, 0, 0, 0))
	_pixels_rect(dagger_img, 7, 0, 2, 8, Color(0.55, 0.55, 0.58))
	_pixels_rect(dagger_img, 6, 1, 1, 3, Color(0.55, 0.55, 0.58))
	_pixels_rect(dagger_img, 9, 1, 1, 3, Color(0.55, 0.55, 0.58))
	_pixels_rect(dagger_img, 7, 7, 2, 1, Color(0.45, 0.45, 0.48))
	_pixels_rect(dagger_img, 7, 8, 2, 7, Color(0.35, 0.30, 0.28))
	_icon_cache["dagger"] = _resize_icon_to_cache(dagger_img)

	# Stun gun icon: cyan coil silhouette
	var stun_img := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	stun_img.fill(Color(0, 0, 0, 0))
	_pixels_rect(stun_img, 0, 5, 14, 6, Color(0.2, 0.6, 0.65))
	_pixels_rect(stun_img, 14, 4, 2, 8, Color(0.2, 0.6, 0.65))
	_pixels_rect(stun_img, 16, 2, 6, 12, Color(0.15, 0.5, 0.55))
	_pixels_rect(stun_img, 22, 4, 8, 8, Color(0.2, 0.6, 0.65))
	_pixels_rect(stun_img, 26, 0, 2, 16, Color(0.0, 0.7, 0.85))
	_pixels_rect(stun_img, 30, 4, 1, 4, Color(0.0, 0.9, 1.0))
	_icon_cache["stun_gun"] = _resize_icon_to_cache(stun_img)

	# Ammo pistol: yellow squares
	var ammo_p_img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	ammo_p_img.fill(Color(0, 0, 0, 0))
	_pixels_rect(ammo_p_img, 3, 6, 10, 5, Color(0.7, 0.65, 0.2))
	_pixels_rect(ammo_p_img, 5, 3, 6, 3, Color(0.85, 0.75, 0.1))
	_pixels_rect(ammo_p_img, 7, 11, 2, 2, Color(0.5, 0.45, 0.15))
	_icon_cache["ammo_pistol"] = _resize_icon_to_cache(ammo_p_img)

	# Ammo stun: cyan squares
	var ammo_s_img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	ammo_s_img.fill(Color(0, 0, 0, 0))
	_pixels_rect(ammo_s_img, 3, 6, 10, 5, Color(0.15, 0.55, 0.6))
	_pixels_rect(ammo_s_img, 5, 3, 6, 3, Color(0.1, 0.7, 0.75))
	_pixels_rect(ammo_s_img, 7, 11, 2, 2, Color(0.1, 0.4, 0.45))
	_icon_cache["ammo_stun"] = _resize_icon_to_cache(ammo_s_img)

	# Flashlight: gray tube silhouette
	var fl_img := Image.create(20, 28, false, Image.FORMAT_RGBA8)
	fl_img.fill(Color(0, 0, 0, 0))
	_pixels_rect(fl_img, 4, 0, 12, 4, Color(0.5, 0.5, 0.52))
	_pixels_rect(fl_img, 5, 4, 10, 3, Color(0.55, 0.55, 0.57))
	_pixels_rect(fl_img, 6, 7, 8, 16, Color(0.38, 0.38, 0.40))
	_pixels_rect(fl_img, 5, 23, 10, 4, Color(0.35, 0.33, 0.30))
	_icon_cache["flashlight"] = _resize_icon_to_cache(fl_img)

	# Flashlight ON: with warm yellow glow
	var fl_on_img := Image.create(20, 28, false, Image.FORMAT_RGBA8)
	fl_on_img.fill(Color(0, 0, 0, 0))
	_pixels_rect(fl_on_img, 2, 0, 4, 28, Color(1.0, 0.85, 0.2, 0.4))
	_pixels_rect(fl_on_img, 14, 0, 4, 28, Color(1.0, 0.85, 0.2, 0.4))
	_pixels_rect(fl_on_img, 4, 0, 12, 4, Color(0.6, 0.55, 0.3))
	_pixels_rect(fl_on_img, 5, 4, 10, 3, Color(0.9, 0.8, 0.3))
	_pixels_rect(fl_on_img, 6, 7, 8, 16, Color(0.38, 0.38, 0.40))
	_pixels_rect(fl_on_img, 5, 23, 10, 4, Color(0.35, 0.33, 0.30))
	_icon_cache["flashlight_on"] = _resize_icon_to_cache(fl_on_img)

	# Empty slot: faint border
	var empty_img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	empty_img.fill(Color(0, 0, 0, 0))
	_pixels_rect(empty_img, 2, 2, 28, 1, Color(0.3, 0.3, 0.32, 0.5))
	_pixels_rect(empty_img, 2, 29, 28, 1, Color(0.3, 0.3, 0.32, 0.5))
	_pixels_rect(empty_img, 2, 3, 1, 26, Color(0.3, 0.3, 0.32, 0.5))
	_pixels_rect(empty_img, 29, 3, 1, 26, Color(0.3, 0.3, 0.32, 0.5))
	_icon_cache["empty"] = ImageTexture.create_from_image(empty_img)


func _pixels_rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for dy in range(h):
		for dx in range(w):
			var px := x + dx
			var py := y + dy
			if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
				img.set_pixel(px, py, color)


func _resize_icon_to_cache(src: Image) -> ImageTexture:
	var dst := Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	dst.fill(Color(0, 0, 0, 0))
	var sw := src.get_width()
	var sh := src.get_height()
	var ox := (ICON_SIZE - sw) / 2
	var oy := (ICON_SIZE - sh) / 2
	for y in range(sh):
		for x in range(sw):
			var c := src.get_pixel(x, y)
			if c.a > 0:
				dst.set_pixel(ox + x, oy + y, c)
	return ImageTexture.create_from_image(dst)


# ============================================================
# Refresh -- populate all slots from player data
# ============================================================

func _refresh() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	for slot in main_slots:
		_clear_slot(slot)
	for slot in hotbar_slots:
		_clear_slot(slot)

	var main_idx := 0

	# --- Flashlight (slot 0) ---
	if player.has_flashlight and main_idx < main_slots.size():
		var fl_on := player.flashlight_on
		_set_slot_item(main_slots[main_idx], "flashlight", {
			"name": "手电筒",
			"state": fl_on,
			"flashlight_on": fl_on,
		})
		main_idx += 1

	# --- Weapons ---
	for w in player.weapon_inventory:
		if main_idx >= main_slots.size():
			break
		_set_slot_item(main_slots[main_idx], "weapon", w)
		main_idx += 1

	# --- Ammo reserves ---
	var reserves: Dictionary = player.ammo_reserves
	if not reserves.is_empty() and main_idx < main_slots.size():
		for ammo_type in reserves:
			if main_idx >= main_slots.size():
				break
			_set_slot_item(main_slots[main_idx], "ammo", {
				"ammo_type": ammo_type,
				"count": reserves[ammo_type],
			})
			main_idx += 1

	# --- Hotbar row ---
	for i in range(min(player.hotbar.size(), hotbar_slots.size())):
		var item = player.hotbar[i]
		if item == null:
			continue
		if item is String and item == "flashlight":
			_set_slot_item(hotbar_slots[i], "flashlight", {
				"name": "手电筒 [%d]" % (i + 1),
				"state": player.flashlight_on,
				"flashlight_on": player.flashlight_on,
			})
		elif item is Weapon:
			_set_slot_item(hotbar_slots[i], "weapon", item)

		if i == player.hotbar_selected:
			hotbar_slots[i].add_theme_stylebox_override("normal", slot_selected_style)
			hotbar_slots[i].add_theme_stylebox_override("pressed", slot_selected_style)


func _clear_slot(slot: Button) -> void:
	slot.set_meta("item", null)
	slot.set_meta("item_kind", "")
	var icon: TextureRect = slot.get_node("Icon")
	var count_label: Label = slot.get_node("Count")
	icon.texture = _icon_cache.get("empty", null)
	count_label.text = ""
	slot.add_theme_stylebox_override("normal", slot_normal_style)
	slot.add_theme_stylebox_override("pressed", slot_normal_style)


func _set_slot_item(slot: Button, kind: String, item_data: Variant) -> void:
	slot.set_meta("item", item_data)
	slot.set_meta("item_kind", kind)
	var icon: TextureRect = slot.get_node("Icon")
	var count_label: Label = slot.get_node("Count")

	match kind:
		"flashlight":
			var d: Dictionary = item_data
			var is_on: bool = d.get("flashlight_on", false)
			icon.texture = _icon_cache.get("flashlight_on" if is_on else "flashlight", _icon_cache.get("empty"))
			count_label.text = ""
		"weapon":
			var w: Weapon = item_data
			var wname: String = w.weapon_name.to_lower()
			if wname.contains("pistol") or wname.contains("手枪"):
				icon.texture = _icon_cache.get("pistol", _icon_cache.get("empty"))
			elif wname.contains("dagger") or wname.contains("匕首") or wname.contains("knife"):
				icon.texture = _icon_cache.get("dagger", _icon_cache.get("empty"))
			elif wname.contains("stun") or wname.contains("电击"):
				icon.texture = _icon_cache.get("stun_gun", _icon_cache.get("empty"))
			else:
				icon.texture = _icon_cache.get("pistol", _icon_cache.get("empty"))
			count_label.text = "%d" % w.current_ammo if w.weapon_kind == Weapon.WeaponKind.RANGED else ""
		"ammo":
			var d: Dictionary = item_data
			var atype: String = d.get("ammo_type", "")
			if atype.contains("pistol"):
				icon.texture = _icon_cache.get("ammo_pistol", _icon_cache.get("empty"))
			elif atype.contains("stun"):
				icon.texture = _icon_cache.get("ammo_stun", _icon_cache.get("empty"))
			else:
				icon.texture = _icon_cache.get("ammo_pistol", _icon_cache.get("empty"))
			count_label.text = "%d" % d.get("count", 0)


# ============================================================
# Tooltip
# ============================================================

func _build_tooltip() -> void:
	tooltip_panel = Panel.new()
	tooltip_panel.name = "TooltipPanel"
	tooltip_panel.visible = false
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.z_index = 100

	var tooltip_style := StyleBoxFlat.new()
	tooltip_style.bg_color = Color(0.08, 0.08, 0.10, 0.92)
	tooltip_style.border_width_left = 1
	tooltip_style.border_width_right = 1
	tooltip_style.border_width_top = 1
	tooltip_style.border_width_bottom = 1
	tooltip_style.border_color = Color(0.5, 0.5, 0.5)
	tooltip_style.corner_radius_top_left = 4
	tooltip_style.corner_radius_top_right = 4
	tooltip_style.corner_radius_bottom_left = 4
	tooltip_style.corner_radius_bottom_right = 4
	tooltip_panel.add_theme_stylebox_override("panel", tooltip_style)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 4)
	tooltip_panel.add_child(margin)

	tooltip_label = RichTextLabel.new()
	tooltip_label.name = "TooltipLabel"
	tooltip_label.fit_content = true
	tooltip_label.scroll_active = false
	tooltip_label.bbcode_enabled = true
	tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_label.add_theme_font_size_override("normal_font_size", 12)
	margin.add_child(tooltip_label)

	add_child(tooltip_panel)


func _on_slot_mouse_entered(slot: Button) -> void:
	_mouse_over_slot = true
	_tooltip_slot = slot
	var kind: String = slot.get_meta("item_kind", "")
	var item = slot.get_meta("item", null)

	if kind == "" or item == null:
		return

	var tt := _format_tooltip_text(kind, item)
	if tt == "":
		return

	tooltip_label.text = tt
	tooltip_panel.visible = true

	var mp := get_global_mouse_position()
	var vp_size := get_viewport().get_visible_rect().size
	# Force layout update for size calculation
	tooltip_panel.size = Vector2.ZERO  # reset to trigger recalc
	var panel_size := tooltip_panel.get_minimum_size()
	var pos := mp + Vector2(16, 16)
	if pos.x + panel_size.x > vp_size.x:
		pos.x = mp.x - panel_size.x - 8
	if pos.y + panel_size.y > vp_size.y:
		pos.y = mp.y - panel_size.y - 8
	tooltip_panel.global_position = pos


func _on_slot_mouse_exited(_slot: Button) -> void:
	_mouse_over_slot = false
	_tooltip_slot = null
	tooltip_panel.visible = false


func _format_tooltip_text(kind: String, item: Variant) -> String:
	match kind:
		"flashlight":
			var d: Dictionary = item
			var state_str := "[color=#ffcc00]开[/color]" if d.get("flashlight_on", false) else "[color=#888888]关[/color]"
			return "[b]手电筒[/b]\n类型: 工具\n状态: %s" % state_str
		"weapon":
			var w: Weapon = item
			var lines: Array[String] = []
			lines.append("[b]%s[/b]" % w.weapon_name)
			if w.weapon_kind == Weapon.WeaponKind.RANGED:
				lines.append("类型: 远程武器")
				lines.append("伤害: %.0f" % w.damage)
				lines.append("弹药: %d / %d" % [w.current_ammo, w.max_ammo])
				lines.append("射速: %.1f/s" % (1.0 / w.fire_rate))
				if w.automatic:
					lines.append("[color=#88aaff]全自动[/color]")
				if w.bullets_per_shot > 1:
					lines.append("弹丸数: %d" % w.bullets_per_shot)
				if w.status_effect != "":
					lines.append("效果: %s (%.1fs)" % [w.status_effect, w.effect_duration])
				var player = get_tree().get_first_node_in_group("player")
				if player and w.ammo_type != "":
					var reserve := player.get_ammo_reserve(w.ammo_type)
					lines.append("储备: %d" % reserve)
			else:
				lines.append("类型: 近战武器")
				lines.append("伤害: %.0f" % w.melee_damage)
				lines.append("范围: %.0f" % w.melee_range)
				lines.append("角度: %.0f" % w.melee_angle)
				if w.status_effect != "":
					lines.append("效果: %s (%.1fs)" % [w.status_effect, w.effect_duration])
			return "\n".join(lines)
		"ammo":
			var d: Dictionary = item
			return "[b]弹药[/b]\n类型: %s\n数量: %d" % [d.get("ammo_type", "?"), d.get("count", 0)]
	return ""


# ============================================================
# Detail Panel (modal)
# ============================================================

func _build_detail_panel() -> void:
	detail_overlay = ColorRect.new()
	detail_overlay.name = "DetailOverlay"
	detail_overlay.color = Color(0, 0, 0, 0.5)
	detail_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	detail_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	detail_overlay.gui_input.connect(_on_overlay_gui_input)
	detail_overlay.visible = false
	detail_overlay.z_index = 50
	add_child(detail_overlay)

	detail_panel = Panel.new()
	detail_panel.name = "DetailPanel"
	detail_panel.set_anchors_preset(Control.PRESET_CENTER)
	detail_panel.custom_minimum_size = Vector2(280, 300)
	detail_panel.z_index = 60
	detail_panel.visible = false

	var dp_style := StyleBoxFlat.new()
	dp_style.bg_color = Color(0.12, 0.12, 0.15, 0.97)
	dp_style.border_width_left = 2
	dp_style.border_width_right = 2
	dp_style.border_width_top = 2
	dp_style.border_width_bottom = 2
	dp_style.border_color = Color(0.5, 0.5, 0.5)
	dp_style.corner_radius_top_left = 4
	dp_style.corner_radius_top_right = 4
	dp_style.corner_radius_bottom_left = 4
	dp_style.corner_radius_bottom_right = 4
	detail_panel.add_theme_stylebox_override("panel", dp_style)

	detail_overlay.add_child(detail_panel)

	var dp_margin := MarginContainer.new()
	dp_margin.name = "Margin"
	dp_margin.add_theme_constant_override("margin_left", 12)
	dp_margin.add_theme_constant_override("margin_top", 12)
	dp_margin.add_theme_constant_override("margin_right", 12)
	dp_margin.add_theme_constant_override("margin_bottom", 12)
	detail_panel.add_child(dp_margin)

	var dp_vbox := VBoxContainer.new()
	dp_vbox.name = "VBox"
	dp_vbox.add_theme_constant_override("separation", 6)
	dp_margin.add_child(dp_vbox)

	# Icon
	detail_icon = TextureRect.new()
	detail_icon.name = "DetailIcon"
	detail_icon.custom_minimum_size = Vector2(64, 64)
	detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	dp_vbox.add_child(detail_icon)

	# Name
	detail_name_label = Label.new()
	detail_name_label.name = "DetailName"
	detail_name_label.add_theme_font_size_override("font_size", 16)
	detail_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dp_vbox.add_child(detail_name_label)

	# Info
	detail_info_label = RichTextLabel.new()
	detail_info_label.name = "DetailInfo"
	detail_info_label.bbcode_enabled = true
	detail_info_label.fit_content = true
	detail_info_label.scroll_active = false
	detail_info_label.add_theme_font_size_override("normal_font_size", 12)
	dp_vbox.add_child(detail_info_label)

	# Button row
	var btn_grid := GridContainer.new()
	btn_grid.name = "BtnGrid"
	btn_grid.columns = 2
	btn_grid.add_theme_constant_override("h_separation", 4)
	btn_grid.add_theme_constant_override("v_separation", 4)
	dp_vbox.add_child(btn_grid)

	detail_equip_btn = Button.new()
	detail_equip_btn.name = "EquipBtn"
	detail_equip_btn.text = "装备"
	detail_equip_btn.custom_minimum_size = Vector2(120, 28)
	detail_equip_btn.pressed.connect(_on_detail_equip)
	btn_grid.add_child(detail_equip_btn)

	detail_unequip_btn = Button.new()
	detail_unequip_btn.name = "UnequipBtn"
	detail_unequip_btn.text = "卸下"
	detail_unequip_btn.custom_minimum_size = Vector2(120, 28)
	detail_unequip_btn.pressed.connect(_on_detail_unequip)
	btn_grid.add_child(detail_unequip_btn)

	detail_hotbar_btn = Button.new()
	detail_hotbar_btn.name = "HotbarBtn"
	detail_hotbar_btn.text = "放入快捷栏"
	detail_hotbar_btn.custom_minimum_size = Vector2(120, 28)
	detail_hotbar_btn.pressed.connect(_on_detail_hotbar)
	btn_grid.add_child(detail_hotbar_btn)

	detail_discard_btn = Button.new()
	detail_discard_btn.name = "DiscardBtn"
	detail_discard_btn.text = "丢弃"
	detail_discard_btn.custom_minimum_size = Vector2(120, 28)
	detail_discard_btn.pressed.connect(_on_detail_discard)
	btn_grid.add_child(detail_discard_btn)

	detail_close_btn = Button.new()
	detail_close_btn.name = "CloseBtn"
	detail_close_btn.text = "关闭"
	detail_close_btn.custom_minimum_size = Vector2(0, 28)
	detail_close_btn.pressed.connect(_close_detail)
	dp_vbox.add_child(detail_close_btn)


func _on_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_detail()


func _show_detail(slot: Button) -> void:
	var kind: String = slot.get_meta("item_kind", "")
	var item = slot.get_meta("item", null)
	if kind == "" or item == null:
		return
	if kind == "ammo":
		return

	detail_item = item
	_set_detail_content(kind, item, slot)

	detail_overlay.visible = true
	detail_panel.visible = true
	detail_panel.position = (detail_overlay.size - detail_panel.size) / 2.0


func _set_detail_content(kind: String, item: Variant, _slot: Button) -> void:
	match kind:
		"flashlight":
			var d: Dictionary = item
			var is_on: bool = d.get("flashlight_on", false)
			detail_icon.texture = _icon_cache.get("flashlight_on" if is_on else "flashlight")
			detail_name_label.text = "手电筒"
			detail_info_label.text = "状态: %s\n\n照明工具，可驱散黑暗。" % ("[color=#ffcc00]开启[/color]" if is_on else "[color=#888888]关闭[/color]")
			detail_equip_btn.visible = false
			detail_unequip_btn.visible = false
			detail_hotbar_btn.visible = true
			detail_hotbar_btn.text = "放入快捷栏"
			detail_discard_btn.visible = false
		"weapon":
			var w: Weapon = item
			var wname: String = w.weapon_name.to_lower()
			if wname.contains("pistol") or wname.contains("手枪"):
				detail_icon.texture = _icon_cache.get("pistol")
			elif wname.contains("dagger") or wname.contains("匕首"):
				detail_icon.texture = _icon_cache.get("dagger")
			elif wname.contains("stun") or wname.contains("电击"):
				detail_icon.texture = _icon_cache.get("stun_gun")
			else:
				detail_icon.texture = _icon_cache.get("pistol")
			detail_name_label.text = w.weapon_name

			var info_lines: Array[String] = []
			if w.weapon_kind == Weapon.WeaponKind.RANGED:
				info_lines.append("[b]远程武器[/b]")
				info_lines.append("伤害: %.0f" % w.damage)
				info_lines.append("弹药: %d / %d" % [w.current_ammo, w.max_ammo])
				info_lines.append("射速: %.1f/秒" % (1.0 / w.fire_rate))
				info_lines.append("弹速: %.0f" % w.bullet_speed)
				if w.automatic:
					info_lines.append("[color=#88aaff]全自动[/color]")
				if w.bullets_per_shot > 1:
					info_lines.append("弹丸: %d" % w.bullets_per_shot)
				if w.spread_angle > 0:
					info_lines.append("散布: %.1f°" % w.spread_angle)
				if w.status_effect != "":
					info_lines.append("效果: %s" % w.status_effect)
				var player = get_tree().get_first_node_in_group("player")
				if player and w.ammo_type != "":
					var reserve := player.get_ammo_reserve(w.ammo_type)
					info_lines.append("\n弹药储备: %d" % reserve)
			else:
				info_lines.append("[b]近战武器[/b]")
				info_lines.append("伤害: %.0f" % w.melee_damage)
				info_lines.append("范围: %.0f" % w.melee_range)
				info_lines.append("角度: %.0f°" % w.melee_angle)
				if w.status_effect != "":
					info_lines.append("效果: %s" % w.status_effect)

			detail_info_label.text = "\n".join(info_lines)

			var player = get_tree().get_first_node_in_group("player")
			var is_equipped := player != null and player.current_weapon == w
			detail_equip_btn.visible = not is_equipped
			detail_unequip_btn.visible = is_equipped
			detail_hotbar_btn.visible = true
			detail_hotbar_btn.text = "放入快捷栏"
			detail_discard_btn.visible = true


func _close_detail() -> void:
	detail_item = null
	detail_overlay.visible = false
	detail_panel.visible = false


# ============================================================
# Slot Interaction
# ============================================================

func _on_slot_pressed(slot: Button) -> void:
	var kind: String = slot.get_meta("item_kind", "")
	var item = slot.get_meta("item", null)

	if detail_overlay.visible and detail_item != null:
		if kind == "weapon" and item is Weapon and item == detail_item:
			_close_detail()
			return
		if kind == "flashlight" and detail_item is Dictionary:
			_close_detail()
			return

	if kind != "" and kind != "ammo" and item != null:
		_show_detail(slot)
		return


# ============================================================
# Detail Button Logic
# ============================================================

func _on_detail_equip() -> void:
	if detail_item == null or not (detail_item is Weapon):
		return
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	player.equip_weapon(detail_item as Weapon)
	_close_detail()
	_refresh()


func _on_detail_unequip() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	player.hotbar_selected = 0
	player._select_hotbar(0)
	_close_detail()
	_refresh()


func _on_detail_hotbar() -> void:
	if detail_item == null:
		return
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	if detail_item is Dictionary:
		player.hotbar[player.hotbar_selected] = "flashlight"
	elif detail_item is Weapon:
		player.hotbar[player.hotbar_selected] = detail_item

	_close_detail()
	_refresh()


func _on_detail_discard() -> void:
	if detail_item == null or not (detail_item is Weapon):
		return
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	player.remove_weapon(detail_item as Weapon)
	_close_detail()
	_refresh()
