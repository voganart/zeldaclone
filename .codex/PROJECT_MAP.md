# Карта проекта ZeldaClone

## Быстрый старт

- Конфигурация: `project.godot`
- Главная сцена: `res://ui/menus/main_menu.tscn`
- Основной игровой уровень: `res://levels/Level_01.tscn`
- Игрок: `res://entities/player/player.tscn`
- Полный текстовый индекс: `.codex/project-index.txt`
- Обновление индекса: `.codex/update-project-index.ps1`

## Директории

| Путь | Назначение |
| --- | --- |
| `common/autoload/` | Глобальные runtime-сервисы: game state, audio, scene loading, graphics, player data, pools. |
| `common/components/` | Переиспользуемые gameplay-компоненты движения, боя, камеры и анимации. |
| `common/fsm/` | Базовая state machine для игровых сущностей. |
| `common/interaction/` | Система интеракций, области взаимодействия и readable objects. |
| `common/persistence/` | Переиспользуемые persistent-ID компоненты для головоломок, наград и постоянных проходов. |
| `common/utils/` | Editor/runtime utilities для растительности, материалов и occlusion. |
| `entities/player/` | Игрок, abilities, states, input и character scenes. |
| `entities/enemies/` | Враги, AI states, компоненты и spawners. |
| `entities/interactive/` | Интерактивные объекты: crates, chests и разрушаемые props. |
| `entities/PickupItems/` | Подбираемые предметы и их сцены. |
| `entities/environment/` | Сцены окружения и сгенерированная растительность. |
| `levels/` | Игровые уровни и test levels. |
| `levels/components/` | Battle arena, environment/day-night, moving platforms, tutorial и clouds. |
| `ui/` | Меню, HUD, tutorial, health UI, prompts и debug overlay. |
| `vfx/` | VFX-сцены и управляющие скрипты: hit, dust, blood, pickup, fade, camera shake. |
| `assets/` | Модели, текстуры, звук, материалы, shaders, UI и translations. |
| `addons/` | Сторонние editor/runtime плагины. Изменения здесь считать vendor patches. |
| `references/` | Визуальные референсы; не участвуют в runtime и исключены из индекса. |

## Gameplay-навигация

- Смена сцен: `common/autoload/scene_manager.gd`
- Дисковые сохранения и checkpoints: `common/autoload/save_manager.gd`
- Runtime-прогресс игрока: `common/autoload/player_data.gd`
- Расставляемый Узел памяти: `entities/interactive/MemoryNode/MemoryNode.tscn`
- Persistent-ID контракт: `common/persistence/persistent_state.gd`
- Глобальное состояние игры: `common/autoload/game_manager.gd`
- События: `common/autoload/game_events.gd`
- AI orchestration: `common/autoload/ai_director.gd`
- Игровой звук: `common/autoload/audio_manager.gd`
- Музыка: `common/autoload/music_brain.gd`
- Input abstraction: `common/autoload/input_helper.gd`
- Player state machine: `entities/player/states/`
- Enemy state machine: `entities/enemies/states/`
- VFX pooling: `common/autoload/VfxPool.tscn` + `vfx/blood_splash/VfxPool.gd`

## Правила поиска

```powershell
# Найти сцену или скрипт
rg -n "имя_узла|имя_метода" -g '*.gd' -g '*.tscn'

# Найти все использования ресурса
rg -n "res://путь/к/ресурсу"

# Обновить компактный индекс
powershell -NoProfile -ExecutionPolicy Bypass -File .codex/update-project-index.ps1
```
