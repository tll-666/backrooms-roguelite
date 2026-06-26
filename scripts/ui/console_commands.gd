## ConsoleCommands — 开发者控制台的具体命令实现集合。
## 每个内部类继承 ConsoleCommand，自包含执行逻辑。
## 参考 odyssey-cards 的 Commands/*Commands.cs，适配为 GDScript 内部类。
##
## 命令清单：
##   /help                显示帮助。别名 /?
##   /clear               清空控制台输出。别名 /cls
##   /god                 切换上帝模式（玩家无敌）。
##   /fog                 切换战争迷雾开启状态。
##   /heal [N]            恢复 N 点生命值，无参数则满血。别名 /h
##   /damage [N]          对自己造成 N 点伤害（默认 10）。别名 /dmg
##   /ammo                当前武器弹药补满（弹夹+储备）。
##   /give_weapon <name>  获得武器到背包。别名 /gw
##   /give_ammo <type> [N]获得 N 点弹药。别名 /ga
##   /weapons             列出背包中所有武器。别名 /wpn
##   /inv                 显示完整背包内容。别名 /bag
##   /kill_all            清空当前楼层所有敌人。别名 /killall
##   /noclip              切换穿墙模式。别名 /nc
##   /sanity [N]          设置理智为 N，无参数则满理智。别名 /san
##   /floor [N]           跳到第 N 层（重新生成楼层）。
##   /currency [N]        增加 N 点局外货币（默认 100）。别名 /gold
##   /restart             重新生成当前楼层。别名 /r
extends RefCounted
class_name ConsoleCommands


# ===== /help =====

class HelpCommand extends ConsoleCommand:
	var _engine: ConsoleEngine = null

	func _init(engine: ConsoleEngine = null) -> void:
		name = "help"
		aliases = PackedStringArray(["?"])
		signature = "/help"
		description = "显示所有可用命令。"
		_engine = engine

	func execute(_args: PackedStringArray) -> Dictionary:
		if _engine == null:
			return _fail("命令引擎未初始化")
		var cmds: Array[ConsoleCommand] = _engine.get_commands()
		if cmds.is_empty():
			return _ok("暂无可用的开发者命令")
		# 去重（按 name）
		var seen: Dictionary = {}
		var unique: Array[ConsoleCommand] = []
		for cmd in cmds:
			if not seen.has(cmd.name):
				seen[cmd.name] = true
				unique.append(cmd)
		unique.sort_custom(_by_name)
		var lines: PackedStringArray = ["=== 开发者命令 ==="]
		for cmd in unique:
			var alias_str: String = ""
			if cmd.aliases.size() > 0:
				alias_str = "（别名: %s）" % ", ".join(cmd.aliases)
			# 对齐：签名占 28 字符宽度
			var sig_padded: String = cmd.signature
			while sig_padded.length() < 28:
				sig_padded += " "
			lines.append("  %s — %s%s" % [sig_padded, cmd.description, alias_str])
		return _ok("\n".join(lines))

	static func _by_name(a: ConsoleCommand, b: ConsoleCommand) -> bool:
		return a.name.to_lower() < b.name.to_lower()


# ===== /clear =====

class ClearCommand extends ConsoleCommand:
	func _init() -> void:
		name = "clear"
		aliases = PackedStringArray(["cls"])
		signature = "/clear"
		description = "清空控制台输出。"

	func execute(_args: PackedStringArray) -> Dictionary:
		return _ok("__CLEAR__")


# ===== /god — 切换上帝模式（玩家无敌）★ =====

class GodCommand extends ConsoleCommand:
	func _init() -> void:
		name = "god"
		signature = "/god"
		description = "切换上帝模式（玩家无敌，免疫所有伤害）。"

	func execute(_args: PackedStringArray) -> Dictionary:
		var p := _player()
		if p == null:
			return _fail("当前场景没有玩家（请先开始一局游戏）")
		if not ("is_invincible" in p):
			return _fail("玩家节点不支持上帝模式（缺少 is_invincible 字段）")
		p.is_invincible = not bool(p.is_invincible)
		var status: String = "开启" if p.is_invincible else "关闭"
		return _ok("上帝模式已%s" % status)


# ===== /fog — 切换战争迷雾 ★ =====

class FogCommand extends ConsoleCommand:
	func _init() -> void:
		name = "fog"
		signature = "/fog"
		description = "切换战争迷雾开启状态。"

	func execute(_args: PackedStringArray) -> Dictionary:
		var fog := _fog_layer()
		if fog == null:
			return _fail("当前场景没有战争迷雾节点（请先进入关卡）")
		fog.visible = not fog.visible
		var status: String = "开启" if fog.visible else "关闭"
		return _ok("战争迷雾已%s" % status)


# ===== /heal [N] =====

class HealCommand extends ConsoleCommand:
	func _init() -> void:
		name = "heal"
		aliases = PackedStringArray(["h"])
		signature = "/heal [N]"
		description = "恢复 N 点生命值，无参数则恢复满血。"

	func execute(args: PackedStringArray) -> Dictionary:
		var p := _player()
		if p == null:
			return _fail("当前场景没有玩家")
		if not p.has_method("heal"):
			return _fail("玩家节点不支持 heal()")
		if args.size() > 0:
			var n: float = float(args[0])
			p.heal(n)
			return _ok("恢复 %.0f 点生命值（当前 %.0f / %.0f）" % [n, float(p.health), float(p.max_health)])
		# 无参数 → 满血
		p.health = float(p.max_health)
		if p.has_signal("health_changed"):
			p.health_changed.emit(p.health, p.max_health)
		return _ok("生命值已恢复满（%.0f / %.0f）" % [float(p.health), float(p.max_health)])


# ===== /damage [N] =====

class DamageCommand extends ConsoleCommand:
	func _init() -> void:
		name = "damage"
		aliases = PackedStringArray(["dmg"])
		signature = "/damage [N]"
		description = "对自己造成 N 点伤害（默认 10），用于测试受伤/死亡。"

	func execute(args: PackedStringArray) -> Dictionary:
		var p := _player()
		if p == null:
			return _fail("当前场景没有玩家")
		if not p.has_method("take_damage"):
			return _fail("玩家节点不支持 take_damage()")
		var n: float = 10.0
		if args.size() > 0:
			n = float(args[0])
		p.take_damage(n)
		return _ok("对自己造成 %.0f 点伤害（当前 %.0f / %.0f）" % [n, float(p.health), float(p.max_health)])


# ===== /ammo =====

class AmmoCommand extends ConsoleCommand:
	func _init() -> void:
		name = "ammo"
		signature = "/ammo"
		description = "当前武器弹药补满（弹夹+储备）。"

	func execute(_args: PackedStringArray) -> Dictionary:
		var p := _player()
		if p == null:
			return _fail("当前场景没有玩家")
		var weapon = p.get("current_weapon")
		if weapon == null:
			return _fail("玩家当前没有武器")
		# 弹药物品化系统：补充储备 + 自动装填
		if p.has_method("add_ammo") and weapon.get("ammo_type") != null:
			var atype: String = str(weapon.ammo_type)
			var clip: int = int(weapon.max_ammo)
			p.add_ammo(atype, clip * 3)  # 3 弹夹储备
			weapon.start_reload()
			var reserve: int = p.get_ammo_reserve(atype)
			return _ok("弹药已补充（%s ×3弹夹，储备 %d）" % [atype, reserve])
		# 旧版退化路径
		weapon.current_ammo = int(weapon.max_ammo)
		if RunManager.has_signal("ammo_changed"):
			RunManager.ammo_changed.emit(int(weapon.current_ammo), int(weapon.max_ammo))
		return _ok("弹药已填满（%d / %d）" % [int(weapon.current_ammo), int(weapon.max_ammo)])


# ===== /kill_all =====

class KillAllCommand extends ConsoleCommand:
	func _init() -> void:
		name = "kill_all"
		aliases = PackedStringArray(["killall"])
		signature = "/kill_all"
		description = "清空当前楼层所有敌人。"

	func execute(_args: PackedStringArray) -> Dictionary:
		var enemies := _all_enemies()
		if enemies.is_empty():
			return _ok("当前没有敌人")
		var count: int = 0
		for enemy in enemies:
			if enemy is Enemy and not enemy.is_dead:
				enemy.die()
				count += 1
		return _ok("已清除 %d 个敌人" % count)


# ===== /noclip =====

class NoclipCommand extends ConsoleCommand:
	func _init() -> void:
		name = "noclip"
		aliases = PackedStringArray(["nc"])
		signature = "/noclip"
		description = "切换穿墙模式（无视碰撞）。"

	func execute(_args: PackedStringArray) -> Dictionary:
		var p := _player()
		if p == null:
			return _fail("当前场景没有玩家")
		if not ("is_noclip" in p):
			return _fail("玩家节点不支持穿墙模式（缺少 is_noclip 字段）")
		p.is_noclip = not bool(p.is_noclip)
		# 穿墙时关闭物理碰撞层，恢复时还原
		if p.is_noclip:
			p.collision_layer = 0
			p.collision_mask = 0
		else:
			p.collision_layer = 2
			p.collision_mask = 1
		var status: String = "开启" if p.is_noclip else "关闭"
		return _ok("穿墙模式已%s" % status)


# ===== /sanity [N] =====

class SanityCommand extends ConsoleCommand:
	func _init() -> void:
		name = "sanity"
		aliases = PackedStringArray(["san"])
		signature = "/sanity [N]"
		description = "设置理智为 N，无参数则恢复满理智。"

	func execute(args: PackedStringArray) -> Dictionary:
		if not GameManager or not RunManager:
			return _fail("RunManager 未就绪")
		if args.size() > 0:
			var n: float = float(args[0])
			RunManager.sanity = clamp(n, 0.0, float(RunManager.max_sanity))
		else:
			RunManager.sanity = float(RunManager.max_sanity)
		if RunManager.has_signal("sanity_changed"):
			RunManager.sanity_changed.emit(RunManager.sanity)
		return _ok("理智值：%.0f / %.0f" % [float(RunManager.sanity), float(RunManager.max_sanity)])


# ===== /floor [N] =====

class FloorCommand extends ConsoleCommand:
	func _init() -> void:
		name = "floor"
		signature = "/floor [N]"
		description = "跳到第 N 层并重新生成（无参数则下一层）。"

	func execute(args: PackedStringArray) -> Dictionary:
		if not RunManager:
			return _fail("RunManager 未就绪")
		var target: int = RunManager.current_floor + 1
		if args.size() > 0:
			target = int(args[0])
			if target < 1:
				return _fail("楼层必须 >= 1")
		RunManager.current_floor = target
		if RunManager.has_signal("floor_changed"):
			RunManager.floor_changed.emit(target)
		# 触发楼层重新生成
		var level_gen := _find_level_generator()
		if level_gen and level_gen.has_method("generate_floor"):
			level_gen.generate_floor()
			return _ok("已跳转到第 %d 层" % target)
		return _ok("楼层计数已设为 %d（需手动 /restart 重新生成）" % target)


# ===== /currency [N] =====

class CurrencyCommand extends ConsoleCommand:
	func _init() -> void:
		name = "currency"
		aliases = PackedStringArray(["gold"])
		signature = "/currency [N]"
		description = "增加 N 点局外货币（默认 100）。"

	func execute(args: PackedStringArray) -> Dictionary:
		if not MetaProgression:
			return _fail("MetaProgression 未就绪")
		var n: int = 100
		if args.size() > 0:
			n = int(args[0])
		MetaProgression.currency += n
		if MetaProgression.has_method("save_progression"):
			MetaProgression.save_progression()
		return _ok("增加 %d 点货币（当前 %d）" % [n, int(MetaProgression.currency)])


# ===== /restart =====

class RestartCommand extends ConsoleCommand:
	func _init() -> void:
		name = "restart"
		aliases = PackedStringArray(["r"])
		signature = "/restart"
		description = "重新生成当前楼层。"

	func execute(_args: PackedStringArray) -> Dictionary:
		var tree := _scene_tree()
		if tree == null:
			return _fail("场景树未就绪")
		var level_gen := _find_level_generator()
		if level_gen == null:
			return _fail("当前不在关卡中（找不到 LevelGenerator）")
		if not level_gen.has_method("generate_floor"):
			return _fail("LevelGenerator 不支持 generate_floor()")
		level_gen.generate_floor()
		return _ok("已重新生成当前楼层")


# ===== /give_weapon <name> =====

class GiveWeaponCommand extends ConsoleCommand:
	const WEAPON_MAP: Dictionary = {
		"pistol": "res://scenes/weapons/pistol.tscn",
		"dagger": "res://scenes/weapons/dagger.tscn",
		"stun_gun": "res://scenes/weapons/stun_gun.tscn",
	}

	func _init() -> void:
		name = "give_weapon"
		aliases = PackedStringArray(["gw"])
		signature = "/give_weapon <name>"
		description = "获得武器到背包（pistol / dagger / stun_gun）。"

	func get_arg_candidates(partial_arg: String) -> Array:
		var result: Array = []
		for wname in WEAPON_MAP:
			if partial_arg.is_empty() or wname.begins_with(partial_arg.to_lower()):
				result.append(candidate(wname, wname, ""))
		return result

	func execute(args: PackedStringArray) -> Dictionary:
		var p := _player()
		if p == null:
			return _fail("当前场景没有玩家")
		if args.size() == 0:
			return _fail("用法: /give_weapon <pistol|dagger|stun_gun>")
		var wname: String = args[0].to_lower()
		if not WEAPON_MAP.has(wname):
			return _fail("未知武器: %s。可选: pistol, dagger, stun_gun" % wname)
		var path: String = WEAPON_MAP[wname]
		var scene: PackedScene = load(path)
		if scene == null:
			return _fail("武器场景加载失败: %s" % path)
		var weapon: Weapon = scene.instantiate()
		if not p.has_method("add_weapon"):
			return _fail("玩家不支持 add_weapon()")
		p.add_weapon(weapon)
		# 赠送起步弹药
		if p.has_method("add_ammo") and weapon.ammo_type != "":
			if p.get_ammo_reserve(weapon.ammo_type) == 0:
				p.add_ammo(weapon.ammo_type, weapon.max_ammo * 3)
		# 放入快捷栏空格
		var hb = p.get("hotbar")
		if hb != null:
			for i in range(4):
				if hb[i] == null:
					hb[i] = weapon
					break
		return _ok("获得 %s 到背包（%s）" % [weapon.weapon_name, "远程" if weapon.weapon_kind == 0 else "近战"])


# ===== /give_ammo <type> [amount] =====

class GiveAmmoCommand extends ConsoleCommand:
	func _init() -> void:
		name = "give_ammo"
		aliases = PackedStringArray(["ga"])
		signature = "/give_ammo <type> [amount]"
		description = "获得弹药（pistol / stun）。默认 3×弹夹。"

	func get_arg_candidates(partial_arg: String) -> Array:
		var types: PackedStringArray = ["pistol", "stun"]
		var result: Array = []
		for t in types:
			if partial_arg.is_empty() or t.begins_with(partial_arg.to_lower()):
				result.append(candidate(t, t, ""))
		return result

	func execute(args: PackedStringArray) -> Dictionary:
		var p := _player()
		if p == null:
			return _fail("当前场景没有玩家")
		if args.size() == 0:
			return _fail("用法: /give_ammo <pistol|stun> [数量]")
		var atype: String = args[0].to_lower()
		if atype != "pistol" and atype != "stun":
			return _fail("未知弹药类型: %s。可选: pistol, stun" % atype)
		if not p.has_method("add_ammo"):
			return _fail("玩家节点不支持弹药系统")
		var amount: int = 30 if atype == "pistol" else 9
		if args.size() >= 2:
			amount = int(args[1])
		p.add_ammo(atype, amount)
		var total: int = p.get_ammo_reserve(atype)
		return _ok("获得 %d × %s 弹药（储备 %d）" % [amount, atype, total])


# ===== /weapons =====

class WeaponsCommand extends ConsoleCommand:
	func _init() -> void:
		name = "weapons"
		aliases = PackedStringArray(["wpn"])
		signature = "/weapons"
		description = "列出背包中所有武器及弹药状态。"

	func execute(_args: PackedStringArray) -> Dictionary:
		var p := _player()
		if p == null:
			return _fail("当前场景没有玩家")
		var inv = p.get("weapon_inventory")
		if inv == null or inv.size() == 0:
			return _ok("背包中没有武器")
		var cur = p.get("current_weapon")
		var lines: PackedStringArray = ["=== 武器背包 ==="]
		for i in range(inv.size()):
			var w = inv[i]
			var marker: String = " ▶" if w == cur else ""
			var kind: String = "远程" if w.weapon_kind == 0 else "近战"
			var reserve: int = 0
			if p.has_method("get_ammo_reserve") and w.weapon_kind == 0:
				reserve = p.get_ammo_reserve(w.ammo_type)
			lines.append("  [%d]%s %s (%s) %d/%d 备%d" % [i + 1, marker, w.weapon_name, kind, w.current_ammo, w.max_ammo, reserve])
		return _ok("\n".join(lines))


# ===== /inv =====

class InventoryCommand extends ConsoleCommand:
	func _init() -> void:
		name = "inv"
		aliases = PackedStringArray(["bag"])
		signature = "/inv"
		description = "显示完整背包（武器 + 快捷栏 + 弹药储备）。"

	func execute(_args: PackedStringArray) -> Dictionary:
		var p := _player()
		if p == null:
			return _fail("当前场景没有玩家")
		var lines: PackedStringArray = ["=== 背包 ==="]

		# 武器
		var inv = p.get("weapon_inventory")
		if inv != null and inv.size() > 0:
			var cur = p.get("current_weapon")
			lines.append("武器 (%d):" % inv.size())
			for i in range(inv.size()):
				var w = inv[i]
				var marker: String = " ▶" if w == cur else ""
				var kind: String = "远程" if w.weapon_kind == 0 else "近战"
				lines.append("  %s%s [%s] %d/%d" % [marker, w.weapon_name, kind, w.current_ammo, w.max_ammo])
		else:
			lines.append("武器: 无")

		# 快捷栏
		var hb = p.get("hotbar")
		var sel = p.get("hotbar_selected")
		if hb != null:
			lines.append("快捷栏 (%d 格):" % hb.size())
			for i in range(hb.size()):
				var item = hb[i]
				var marker: String = " ▶" if i == sel else ""
				if item is String and item == "flashlight":
					lines.append("  [%d]%s 手电筒" % [i + 1, marker])
				elif item is Weapon:
					lines.append("  [%d]%s %s" % [i + 1, marker, item.weapon_name])
				else:
					lines.append("  [%d]%s (空)" % [i + 1, marker])

		# 弹药储备
		if p.has_method("get_ammo_reserve"):
			var reserves: Dictionary = p.ammo_reserves
			if not reserves.is_empty():
				lines.append("弹药储备:")
				for atype in reserves:
					lines.append("  %s: %d" % [atype, reserves[atype]])
			else:
				lines.append("弹药储备: 无")

		return _ok("\n".join(lines))
