# Backrooms Roguelite

横版后室探索射击 Roguelite 草稿项目。当前版本是 `0.1.0`，使用 Godot 4.7、GDScript、2D `gl_compatibility` 渲染，主场景为 `res://scenes/ui/main_menu.tscn`。

## 当前状态

- 主循环：主菜单 → 运行关卡 → 死亡结算 → 重试或返回菜单。
- 关卡：`LevelGenerator` 在运行时生成房间网格，实例化 `room_template.tscn`，再放置玩家、敌人和拾取物。
- **武器系统**：手枪（远程）、匕首（近战+刀光）、定身枪（远程+晕眩效果）。攻击统一入口 `attack()`，弹药采用弹夹+储备双轨制，换弹时从储备拉取。
- **背包系统**：类 Minecraft 9×3 网格 + 底行快捷栏，像素图标，悬停 tooltip，点击详情窗。按 B 打开。
- **弹药系统**：手枪子弹 / 定身枪子弹独立储备，拾取补充，HUD 显示弹夹/储备，黄色换弹进度条。
- **控制台**：按 `` ` ``呼出，`/give_weapon`、`/give_ammo`、`/inv`、`/weapons` 等命令用于敏捷 QA。
- 美术：多数精灵在 GDScript 中程序化生成（`Image.create` 模式）；武器贴图在 `weapon.gd:_generate_sprite()` 中生成。
- 自动化：暂未配置测试、导出预设或 CI。

## 运行

需求：Godot 4.7。仓库目前是纯 GDScript；`project.godot` 里出现过 `.NET` 配置，但没有 `.csproj` 或 `.sln`。

```bash
godot --path .
```

也可以直接用 Godot 编辑器打开项目并运行主场景。

## 操作

| 动作 | 输入 |
| --- | --- |
| 移动 | WASD / 方向键 |
| 射击 | 鼠标左键 |
| 换弹 | R |
| 交互 | E |
| 冲刺 | Space |
| 暂停 | Escape |
| 背包 | B |
| 切换武器 | 1 / 2 / 3 / 4 |
| 控制台 | ` |

## 项目结构

```text
.
├── project.godot                 # Godot 项目配置、autoload、输入映射
├── scenes/
│   ├── ui/                       # 主菜单、升级、游戏结束、设置界面
│   ├── levels/                   # 游戏关卡根场景、房间模板、宝箱、传送门
│   ├── weapons/                  # 手枪、匕首、定身枪、子弹场景
│   └── pickups/                  # 拾取物场景（8 种：弹药/武器/医疗/理智/货币）
├── scripts/
│   ├── systems/                  # GameManager、RunManager、MetaProgression、AudioManager、Pickup、Settings、McpInteractionServer
│   ├── levels/                   # 房间、关卡生成、敌人/物品生成器、战争迷雾
│   ├── player/                   # 玩家（500+ 行：移动、冲刺、武器管理、弹药储备）
│   ├── enemies/                  # 敌人 AI 与伤害（含晕眩状态）
│   ├── weapons/                  # 武器系统（RANGED/MELEE 枚举、攻击、装填、刀光）
│   └── ui/                       # 菜单、HUD、背包、热键栏、控制台（见 scripts/ui/AGENTS.md）
├── assets/sprites/               # 当前只有 player.png 及导入元数据
└── generate_player.py            # 旧的 Python/Pillow 精灵生成工具，非运行时依赖
```

## 运行时入口

`project.godot` 注册了 7 个 autoload：

| 单例 | 文件 | 职责 |
| --- | --- | --- |
| `GameManager` | `scripts/systems/game_manager.gd` | 游戏状态、暂停/恢复、场景切换 |
| `RunManager` | `scripts/systems/run_manager.gd` | 当前楼层、理智、击杀、清理房间、运行时间 |
| `MetaProgression` | `scripts/systems/meta_progression.gd` | 局外货币、升级、`user://meta_progression.save` 存档 |
| `AudioManager` | `scripts/systems/audio_manager.gd` | 音乐、音效池、音量控制 |
| `Settings` | `scripts/systems/settings.gd` | 持久化设置（`user://settings.json`），音量/开发者模式 |
| `McpInteractionServer` | `scripts/systems/mcp_interaction_server.gd` | Godot MCP TCP 远程交互（~4200 行，项目最大文件） |
| `Console` | `scripts/ui/console.gd` | 开发者控制台（按 ` 呼出，13 条命令） |

场景流：

```text
scenes/ui/main_menu.tscn
  └─ GameManager.start_run()
      └─ scenes/levels/game_level.tscn
          └─ LevelGenerator.generate_floor()
              ├─ room_template.tscn × N
              ├─ EnemySpawner.spawn_enemies()
              └─ ItemSpawner.spawn_items()
```

玩家死亡后调用 `GameManager.game_over()`，奖励写入 `MetaProgression`，延迟 2 秒进入 `scenes/ui/game_over.tscn`。

## 已知草稿债务

- 根目录以前没有 `.gitignore`，Godot 编辑器缓存、`.codegraph/` 和 `.omo/` 容易污染工作区。
- 没有测试框架、导出预设或 CI。当前验证方式是运行项目并手动走主菜单、开局、移动/射击/受伤/死亡/结算。
- `generate_player.py` 内含旧的本机绝对路径，使用前应改成相对路径或视为历史工具。
- 多个数据表仍硬编码在脚本中：升级成本、敌人类型、武器参数等。项目进入正式制作前应考虑转为 Resource。
- 玩家和敌人的像素图在运行时生成，改美术等同改代码。
