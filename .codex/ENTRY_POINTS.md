# Точки входа

## Application

- Project: `project.godot`
- Main scene UID: `uid://3um71gotlboh`
- Main scene path: `res://ui/menus/main_menu.tscn`
- Main menu script: `res://ui/menus/main_menu.gd`
- Gameplay scene: `res://levels/Level_01.tscn`
- Gameplay controller: `res://levels/level_01.gd`

## Autoload

| Имя | Ресурс | Роль |
| --- | --- | --- |
| `PhantomCameraManager` | `res://addons/phantom_camera/scripts/managers/phantom_camera_manager.gd` | Глобальный manager Phantom Camera. |
| `SimpleGrass` | `res://addons/simplegrasstextured/singleton.tscn` | Runtime/editor singleton травы. |
| `GameEvents` | `res://common/autoload/game_events.gd` | Глобальная event bus. |
| `AIDirector` | `res://common/autoload/ai_director.gd` | Координация AI. |
| `GameManager` | `res://common/autoload/game_manager.gd` | Состояние и flow игры. |
| `AudioManager` | `res://common/autoload/audio_manager.gd` | SFX и общая работа со звуком. |
| `MusicBrain` | `res://common/autoload/music_brain.gd` | Музыкальная логика. |
| `InteractionManager` | `res://common/interaction/interaction_manager.gd` | Глобальная система интеракций. |
| `ItemPool` | `res://common/autoload/ItemPool.tscn` | Pool pickup/items. |
| `VfxPool` | `res://common/autoload/VfxPool.tscn` | Pool визуальных эффектов. |
| `GraphicsManager` | `res://common/autoload/graphics_manager.gd` | Графические настройки. |
| `SceneManager` | `res://common/autoload/scene_manager.gd` | Загрузка и переходы между сценами. |
| `PlayerData` | `res://common/autoload/player_data.gd` | Данные игрока. |
| `SaveManager` | `res://common/autoload/save_manager.gd` | Дисковые сохранения и checkpoints. |
| `DebugTools` | `res://common/autoload/debug_tools.gd` | Debug-only F10-панель и runtime test actions. |
| `InputHelper` | `res://common/autoload/input_helper.gd` | Input abstraction и device handling. |

## Enabled editor plugins

- `res://addons/jigglebones/plugin.cfg`
- `res://addons/phantom_camera/plugin.cfg`
- `res://addons/proton_scatter/plugin.cfg`
- `res://addons/script_spliter/plugin.cfg`
- `res://addons/simplegrasstextured/plugin.cfg`

## Core scenes

- Player: `res://entities/player/player.tscn`
- Player character: `res://entities/player/character.tscn`
- HUD: `res://ui/player_hud.tscn`
- F10 Debug Panel: `res://ui/debug_panel/debug_panel.tscn`
- Loading: `res://ui/menus/loading_screen.tscn`
- Game over: `res://ui/menus/game_over.tscn`
- Interaction area: `res://common/interaction/InteractionArea.tscn`
- Environment system: `res://levels/components/Environment/environment_system.tscn`
- Battle arena: `res://levels/components/BattleArena/BattleArena.tscn`
