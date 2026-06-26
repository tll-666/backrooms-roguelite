## Console — 开发者控制台 autoload。
## 按反引号键 (`) 呼出/隐藏。支持文本命令（/help、/god、/fog 等）。
## 参考 odyssey-cards 的 ChatScreen（C#），适配为 GDScript。
##
## AI 调用方式（godot-mcp）：
##   game_call_method(nodePath="/root/Console", method="dev_command", args=["/god"])
extends CanvasLayer

const HISTORY_PATH: String = "user://console_history.log"
const PANEL_WIDTH: float = 820.0
const PANEL_HEIGHT: float = 420.0

var _panel: Panel = null
var _output: RichTextLabel = null
var _input_field: LineEdit = null
var _send_button: Button = null
var _completion_label: RichTextLabel = null
var _completion_debounce_timer: Timer = null

var _visible: bool = false
var _engine: ConsoleEngine = null
var _history_index: int = 0

# ===== 补全状态 =====
var _completion_candidates: Array = []
var _selected_completion_index: int = -1
var _pending_completion_input: String = ""
var _last_completion_label_text: String = ""


func _ready() -> void:
	# 控制台在最顶层，且暂停时也能响应
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS

	_engine = ConsoleEngine.new()
	_register_all_commands()
	_engine.load_history(ProjectSettings.globalize_path(HISTORY_PATH))

	_build_ui()
	_hide()

	if Settings.dev_mode:
		_write_line("[color=#66ff66][Console] 按 ` 键呼出/隐藏。输入 /help 查看命令。[/color]")
	else:
		_write_line("[color=#888888][Console] 开发者模式未开启。请在设置中勾选「开发者模式」后按 ` 呼出。[/color]")


func _build_ui() -> void:
	# 半透明背景面板
	_panel = Panel.new()
	_panel.name = "ConsolePanel"
	_panel.size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	_panel.position = Vector2(60, 40)
	_panel.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.05, 0.1, 0.94)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.3, 0.6, 0.3)
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_left = 4
	panel_style.corner_radius_bottom_right = 4
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	# VBox 布局
	var vbox := VBoxContainer.new()
	vbox.anchor_left = 0.0
	vbox.anchor_top = 0.0
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 8.0
	vbox.offset_top = 8.0
	vbox.offset_right = -8.0
	vbox.offset_bottom = -8.0
	_panel.add_child(vbox)

	# 标题栏
	var title := Label.new()
	title.text = "  开发者控制台"
	title.custom_minimum_size = Vector2(0, 28)
	title.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	# 输出区域
	_output = RichTextLabel.new()
	_output.name = "Output"
	_output.bbcode_enabled = true
	_output.scroll_following = true
	_output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.custom_minimum_size = Vector2(0, 300)
	_output.add_theme_font_size_override("normal_font_size", 13)
	_output.add_theme_font_size_override("mono_font_size", 13)
	vbox.add_child(_output)

	# 输入栏
	var input_row := HBoxContainer.new()
	input_row.custom_minimum_size = Vector2(0, 34)
	input_row.add_theme_constant_override("separation", 8)
	vbox.add_child(input_row)

	_input_field = LineEdit.new()
	_input_field.name = "Input"
	_input_field.placeholder_text = "输入 /help 查看命令，或 /god /fog /heal 等"
	_input_field.custom_minimum_size = Vector2(0, 32)
	_input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input_field.text_changed.connect(_on_text_changed)
	input_row.add_child(_input_field)

	_send_button = Button.new()
	_send_button.name = "SendButton"
	_send_button.text = "执行"
	_send_button.custom_minimum_size = Vector2(86, 32)
	_send_button.pressed.connect(_submit_current_input)
	input_row.add_child(_send_button)

	# 补全提示
	_completion_label = RichTextLabel.new()
	_completion_label.name = "Completion"
	_completion_label.bbcode_enabled = true
	_completion_label.fit_content = true
	_completion_label.scroll_following = true
	_completion_label.custom_minimum_size = Vector2(0, 0)
	vbox.add_child(_completion_label)

	# 补全防抖 Timer
	_completion_debounce_timer = Timer.new()
	_completion_debounce_timer.name = "CompletionDebounceTimer"
	_completion_debounce_timer.one_shot = true
	_completion_debounce_timer.wait_time = 0.03
	_completion_debounce_timer.autostart = false
	_completion_debounce_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_completion_debounce_timer.timeout.connect(_flush_pending_completion_hint)
	add_child(_completion_debounce_timer)


# ===== 输入处理 =====

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		# 点击控制台外的空白处时取消输入框焦点
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _visible and _input_field.has_focus() and not _panel.get_global_rect().has_point(event.global_position):
				_input_field.release_focus()
		return

	var key: InputEventKey = event
	# 反引号键呼出/隐藏（不依赖 InputMap，避免与项目输入映射耦合）
	# 仅开发者模式开启时可用；未开启时在 _ready 提示一次。
	if key.keycode == KEY_QUOTELEFT:
		if not Settings.dev_mode:
			return
		toggle()
		get_viewport().set_input_as_handled()
		return

	if not _visible:
		return

	if not _input_field.has_focus():
		return

	if key.keycode == KEY_TAB and _try_accept_selected_completion():
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_UP:
		if _completion_candidates.size() > 0 and _try_move_completion_selection(-1):
			pass
		else:
			_navigate_history(-1)
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_DOWN:
		if _completion_candidates.size() > 0 and _try_move_completion_selection(1):
			pass
		else:
			_navigate_history(1)
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		# 不用 LineEdit.TextSubmitted 信号：Godot 4 emit 后会释放焦点导致状态分叉
		_on_command_submitted(_input_field.text)
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_ESCAPE:
		_hide()
		get_viewport().set_input_as_handled()


# ===== 可见性 =====

func toggle() -> void:
	if _visible:
		_hide()
	else:
		_show()

func _show() -> void:
	_visible = true
	_panel.visible = true
	_completion_label.visible = true
	_input_field.grab_focus()
	_input_field.clear()
	_reset_completion_state()
	_on_text_changed("")

func _hide() -> void:
	_visible = false
	_panel.visible = false
	_completion_label.visible = false
	_input_field.release_focus()
	_reset_completion_state()


# ===== 命令处理 =====

func _on_command_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	_input_field.clear()
	_reset_completion_state()
	_execute_console_input(text)

func _submit_current_input() -> void:
	_on_command_submitted(_input_field.text)
	# SendButton 点击会抢占焦点，延迟恢复
	if _visible and is_instance_valid(_input_field):
		call_deferred("_regrab_input_focus")

func _regrab_input_focus() -> void:
	if not _visible or not is_instance_valid(_input_field):
		return
	_input_field.grab_focus()

## 统一的输入提交入口：以 / 开头则执行命令，否则提示。
func _execute_console_input(input: String) -> void:
	input = input.strip_edges()
	if input.is_empty():
		return
	if input.begins_with("/"):
		_execute_command(input)
		return
	# 无 / 前缀：尝试匹配命令名
	var first_token: String = input.split(" ", false, 1)[0] if " " in input else input
	if _engine.try_resolve(first_token) != null:
		_execute_command("/" + input)
		return
	_write_line("[color=#aaaaaa]> %s[/color]" % _escape_bbcode(input))
	_write_line("[color=#ff6644]非命令输入请以 / 开头。输入 /help 查看可用命令。[/color]")

func _execute_command(cmd: String) -> void:
	cmd = cmd.strip_edges()
	_write_line("[color=#aaaaaa]> %s[/color]" % _escape_bbcode(cmd))
	if cmd.is_empty():
		return
	var result: Dictionary = _engine.execute(cmd)
	if not bool(result.get("success", false)):
		_write_line("[color=#ff6644]%s[/color]" % String(result.get("message", "")))
		return
	var msg: String = String(result.get("message", ""))
	if msg == "__CLEAR__":
		_output.clear()
	elif msg.is_empty():
		pass
	else:
		_write_line("[color=#66ff66]%s[/color]" % msg)
	_engine.save_history(ProjectSettings.globalize_path(HISTORY_PATH))


# ===== 输出 =====

func _write_line(text: String) -> void:
	_output.append_text(text + "\n")

## AI 远程调用入口（godot-mcp）。
func dev_command(cmd: String) -> void:
	_execute_command(cmd)


# ===== 历史导航 =====

func _navigate_history(direction: int) -> void:
	var count: int = _engine.history.size()
	if count == 0:
		return
	_history_index = clamp(_history_index + direction, 0, count - 1)
	_input_field.text = _engine.history[_history_index]
	_input_field.caret_column = _input_field.text.length()


# ===== 补全 =====

func _on_text_changed(text: String) -> void:
	_pending_completion_input = text
	_completion_debounce_timer.start()

func _flush_pending_completion_hint() -> void:
	_refresh_completion_hint(_pending_completion_input)

func _refresh_completion_hint(input: String) -> void:
	_completion_candidates.clear()
	for c in _get_completions(input):
		_completion_candidates.append(c)
	_ensure_valid_completion_selection()

	var label_text: String
	if _completion_candidates.is_empty():
		if input.is_empty():
			label_text = ""
		else:
			label_text = "[color=#888888]Enter 执行；输入 / 或命令名前缀可补全[/color]"
	else:
		label_text = _render_completion_candidates(_get_completion_header(input))
	_set_completion_label_text(label_text)

func _set_completion_label_text(text: String) -> void:
	if _last_completion_label_text == text:
		return
	_completion_label.text = text
	_last_completion_label_text = text

func _get_completion_header(input: String) -> String:
	if input.is_empty() or not input.begins_with("/"):
		return "匹配命令（Tab 补全，↑↓ 切换）"
	var content: String = input.substr(1)
	var space_idx: int = content.find(" ")
	if space_idx < 0:
		return "匹配命令（Tab 补全，↑↓ 切换）"
	return "可用参数（Tab 补全，↑↓ 切换）"

func _get_completions(input: String) -> Array:
	if input.strip_edges().is_empty():
		return []
	if input.begins_with("/"):
		return _engine.get_completions(input)
	# 无 / 前缀的命令名补全
	var token: String = input.split(" ", false, 1)[0] if " " in input else input
	if token.is_empty():
		return []
	# 只在 token 是纯字母/下划线/连字符时尝试
	for ch in token:
		if not (ch in "_-" or (ch >= "A" and ch <= "Z") or (ch >= "a" and ch <= "z")):
			return []
	var result: Array = []
	var seen: Dictionary = {}
	for cmd in _engine.get_commands():
		if seen.has(cmd.name):
			continue
		seen[cmd.name] = true
		if not cmd.name.to_lower().begins_with(token.to_lower()):
			var has_alias := false
			for alias in cmd.aliases:
				if alias.to_lower().begins_with(token.to_lower()):
					has_alias = true
					break
			if not has_alias:
				continue
		var signature_tail: String = ""
		var sig_space: int = cmd.signature.find(" ")
		if sig_space >= 0:
			signature_tail = cmd.signature.substr(sig_space + 1)
		result.append(ConsoleCommand.candidate(
			cmd.name + " ",
			(cmd.name + " " + signature_tail).strip_edges(),
			"命令 — " + cmd.description
		))
		if result.size() >= 8:
			break
	return result

func _render_completion_candidates(header: String) -> String:
	var lines: PackedStringArray = ["[color=#aaaaaa]%s[/color]" % header]
	for i in range(_completion_candidates.size()):
		var candidate: Dictionary = _completion_candidates[i]
		var is_selected: bool = (i == _selected_completion_index)
		var prefix: String = "[color=#ffdd66]▶[/color]" if is_selected else "  "
		var primary: String = String(candidate.get("primary_text", ""))
		if is_selected:
			primary = "[color=#ffffff][b]%s[/b][/color]" % primary
		else:
			primary = "[color=#66ff66]%s[/color]" % primary
		var secondary: String = String(candidate.get("secondary_text", ""))
		if not secondary.is_empty():
			secondary = " [color=#888888]— %s[/color]" % secondary
		lines.append("%s %s%s" % [prefix, primary, secondary])
	return "\n".join(lines)

func _ensure_valid_completion_selection() -> void:
	if _completion_candidates.is_empty():
		_selected_completion_index = -1
		return
	if _selected_completion_index < 0 or _selected_completion_index >= _completion_candidates.size():
		_selected_completion_index = 0

func _try_move_completion_selection(direction: int) -> bool:
	if _completion_candidates.is_empty():
		return false
	_selected_completion_index = (_selected_completion_index + direction + _completion_candidates.size()) % _completion_candidates.size()
	_set_completion_label_text(_render_completion_candidates(_get_completion_header(_input_field.text)))
	return true

func _try_accept_selected_completion() -> bool:
	if _selected_completion_index < 0 or _selected_completion_index >= _completion_candidates.size():
		return false
	var insert_text: String = String(_completion_candidates[_selected_completion_index].get("insert_text", ""))
	_input_field.text = insert_text
	_input_field.caret_column = insert_text.length()
	_refresh_completion_hint(insert_text)
	return true

func _reset_completion_state() -> void:
	_completion_candidates.clear()
	_selected_completion_index = -1
	_pending_completion_input = ""
	_set_completion_label_text("")


# ===== 工具 =====

func _escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]").replace("]", "[rb]")


# ===== 命令注册 =====

func _register_all_commands() -> void:
	# help 命令需要引擎引用来列出所有命令
	_engine.register(ConsoleCommands.HelpCommand.new(_engine))
	_engine.register(ConsoleCommands.ClearCommand.new())
	_engine.register(ConsoleCommands.GodCommand.new())
	_engine.register(ConsoleCommands.FogCommand.new())
	_engine.register(ConsoleCommands.HealCommand.new())
	_engine.register(ConsoleCommands.DamageCommand.new())
	_engine.register(ConsoleCommands.AmmoCommand.new())
	_engine.register(ConsoleCommands.GiveWeaponCommand.new())
	_engine.register(ConsoleCommands.GiveAmmoCommand.new())
	_engine.register(ConsoleCommands.WeaponsCommand.new())
	_engine.register(ConsoleCommands.InventoryCommand.new())
	_engine.register(ConsoleCommands.KillAllCommand.new())
	_engine.register(ConsoleCommands.NoclipCommand.new())
	_engine.register(ConsoleCommands.SanityCommand.new())
	_engine.register(ConsoleCommands.FloorCommand.new())
	_engine.register(ConsoleCommands.CurrencyCommand.new())
	_engine.register(ConsoleCommands.RestartCommand.new())
