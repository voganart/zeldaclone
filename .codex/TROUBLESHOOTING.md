# Диагностика запуска

## Environment

- Engine: Godot `4.7.1.stable.steam.a13da4feb`
- Previous project feature tag: Godot `4.6`
- Main scene: `res://ui/menus/main_menu.tscn`
- Steam executable: `C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`

## Проверочные команды

Editor parse:

```powershell
& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' `
  --headless --editor --path 'C:\GodotProjects\zeldaclone' --quit
```

Main scene:

```powershell
& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' `
  --headless --path 'C:\GodotProjects\zeldaclone' --quit-after 180
```

GUI editor smoke-test:

```powershell
& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' `
  --editor --path 'C:\GodotProjects\zeldaclone' --quit-after 300
```

## Подтверждённая ошибка миграции

Первый реальный compatibility blocker находился в `res://addons/proton_scatter/src/scatter.gd:241`: `_get(property)` завершался без возвращаемого значения. Godot 4.7.1 блокировал компиляцию Proton Scatter и зависимых editor scripts. Исправление: явный `return null`.

Regression-test:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .codex/tests/godot-47-compat.tests.ps1
```

## Crash при открытии BattleArena

Точное воспроизведение:

```powershell
& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' `
  --editor 'C:\GodotProjects\zeldaclone\levels\components\BattleArena\BattleArena.tscn' `
  --quit-after 600 --verbose
```

Сцена, её CSG и shader загружались успешно. Crash происходил после загрузки в `res://addons/phantom_camera/scripts/panel/viewfinder/viewfinder.gd`: Viewfinder вызывал `get_phantom_camera_hosts()` у уже освобождённого `PhantomCameraManager`. Backtrace: `_visibility_check()` → `_node_added_to_scene()`, затем `signal 11`.

Исправление: validity guards в `_visibility_check()` и `_assign_manager()`. Проверка:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .codex/tests/battle-arena-editor.tests.ps1
```

## Результат

- Editor parse-check вне ограниченной песочницы: exit code `0`.
- Main scene smoke-check: exit code `0`.
- GUI editor smoke-check: exit code `0`.
- BattleArena editor regression-test: exit code `0`.
- Исходный пользовательский crash после этих проверок больше не воспроизводится.

## Что было артефактом песочницы

При запрете доступа к Godot `user://` тестовый процесс падал с `signal 11` и не мог читать certificate store или сохранять editor settings. В обычном пользовательском окружении тот же запуск проходит. Это не ошибка gameplay-кода.

## Если crash вернётся

1. Закрыть все процессы Godot.
2. Сохранить `git status --short`.
3. Переименовать `.godot` в резервную папку, не удаляя её.
4. Повторить editor parse-команду и дождаться полного reimport.
5. Сравнить первый fatal error с разделом совместимости.
