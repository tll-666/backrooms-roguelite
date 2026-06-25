# Backrooms Roguelite 项目知识库

**生成时间：** 2026-06-25  
**分支：** `master`  
**项目性质：** Godot 4.7 草稿项目，纯 GDScript，横版后室探索射击 Roguelite。

## 概览

入口是 `scenes/ui/main_menu.tscn`。核心游戏流由 4 个 autoload 驱动：`GameManager` 管场景和状态，`RunManager` 管单局数据，`MetaProgression` 管局外成长，`AudioManager` 管音频。

这是早期草稿，不要过度设计层级文档；根级说明足够。

## 结构

```text
.
├── project.godot          # 主场景、autoload、输入映射、渲染/物理设置
├── scenes/ui/             # main_menu、upgrades_screen、game_over
├── scenes/levels/         # game_level 根场景、room_template 房间模板
├── scripts/systems/       # GameManager、RunManager、MetaProgression、AudioManager、Pickup
├── scripts/levels/        # LevelGenerator、Room、EnemySpawner、ItemSpawner
├── scripts/player/        # Player
├── scripts/enemies/       # Enemy
├── scripts/weapons/       # Weapon、Bullet
├── scripts/ui/            # UI 控制脚本
└── assets/sprites/        # 当前只有 player.png，且运行时玩家图不是从它加载
```

## 去哪里改

| 任务 | 位置 | 注意 |
| --- | --- | --- |
| 场景流、暂停、游戏结束 | `scripts/systems/game_manager.gd` | `start_run()` 切到 `game_level.tscn`，`game_over()` 延迟后切结算 |
| 单局数值：楼层/理智/击杀 | `scripts/systems/run_manager.gd` | 理智归零会触发游戏结束 |
| 局外升级和存档 | `scripts/systems/meta_progression.gd` | 存到 `user://meta_progression.save`，当前是明文 JSON |
| 玩家移动、冲刺、受伤 | `scripts/player/player.gd` | 文件偏大，程序化精灵占很多行 |
| 武器和子弹 | `scripts/weapons/weapon.gd`, `scripts/weapons/bullet.gd` | `Weapon` 生成 `Bullet`，伤害受 `MetaProgression` 影响 |
| 敌人 AI | `scripts/enemies/enemy.gd` | 状态目前是字符串：`idle/patrol/chase/attack` |
| 房间与门 | `scripts/levels/room.gd` | 根据连接动态生成墙体碰撞和门洞 |
| 关卡生成 | `scripts/levels/level_generator.gd` | `_ready()` 中直接 `generate_floor()` |
| HUD 与 UI | `scripts/ui/` | UI 文案是中文，标识符是英文 |

## 代码地图

| 符号 | 类型 | 位置 | 角色 |
| --- | --- | --- | --- |
| `GameManager` | Autoload | `scripts/systems/game_manager.gd` | 全局状态机、场景切换 |
| `RunManager` | Autoload | `scripts/systems/run_manager.gd` | 当前 run 数据、理智、楼层 |
| `MetaProgression` | Autoload | `scripts/systems/meta_progression.gd` | 货币、升级、存档 |
| `AudioManager` | Autoload | `scripts/systems/audio_manager.gd` | SFX 池和音乐播放器 |
| `LevelGenerator` | `Node2D` | `scripts/levels/level_generator.gd` | 生成房间布局并放置实体 |
| `Room` | `Node2D` | `scripts/levels/room.gd` | 房间连接、门洞、碰撞墙 |
| `Player` | `CharacterBody2D` | `scripts/player/player.gd` | 移动、冲刺、武器、死亡 |
| `Enemy` | `CharacterBody2D` | `scripts/enemies/enemy.gd` | 巡逻/追击/攻击、受击死亡 |
| `Weapon` | `Node2D` | `scripts/weapons/weapon.gd` | 弹药、射击、装填 |
| `Bullet` | `Area2D` | `scripts/weapons/bullet.gd` | 直线飞行、命中敌人或墙体 |
| `Pickup` | `Area2D` | `scripts/systems/pickup.gd` | 治疗、弹药、理智、武器、货币拾取 |

## 项目约定

- 文件名用 `snake_case`，`class_name`/autoload 用 `PascalCase`。
- 目录按领域分：`scripts/systems`、`scripts/levels`、`scripts/ui` 等；不要为了小改新增抽象目录。
- UI 文案当前是中文；代码标识符保持英文。
- Godot `.import` 元数据如果对应源资源已跟踪，可以保留；不要手动编辑 `.import`。
- `.godot/`、`.codegraph/`、`.omo/` 是本地/工具产物，不应进入新提交。
- `generate_player.py` 是旧工具，不是游戏运行依赖；里面有历史绝对路径，运行前必须先修正。

## 项目特有注意点

- 多数精灵在运行时用 `Image.create()` 生成。改玩家/敌人外观会改 GDScript，而不只是换图片。
- `game_level.tscn` 的根节点就是 `LevelGenerator`，生成逻辑与场景生命周期耦合。
- `project.godot` 启用了 `physics/2d/run_on_separate_thread=true`。
- 项目有 `[dotnet]` 配置痕迹，但没有 C# 项目文件；除非明确启用 C#，不要继续扩展这条线。
- 当前没有测试、导出预设、CI。验证必须以 Godot 运行项目为准。

## 命令

```bash
# 运行项目
godot --path .

# 旧精灵工具；需要 Pillow，且脚本路径应先改成相对路径
python generate_player.py
```

## 手动 QA 面

每次改核心脚本后至少跑一遍：主菜单开始游戏 → 进入关卡 → WASD 移动 → Space 冲刺 → 鼠标射击 → R 换弹 → 被敌人接触受伤 → 死亡进入结算 → 重试/返回菜单。

没有自动化测试时，不要只靠脚本静态检查宣布完成。
