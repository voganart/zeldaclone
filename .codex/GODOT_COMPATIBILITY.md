# Совместимость Godot

Проверено: 2026-07-29.

## Engine

- Текущая версия: Godot `4.7.1.stable.steam.a13da4feb`.
- Предыдущая версия проекта: Godot `4.6`.
- `project.godot` уже мигрирован на feature tag `4.7`.
- Editor parse-check: проходит.
- GUI editor smoke-check: проходит.
- Runtime save-system test ранее проходил через `--script`, но Steam-сборка Godot
  нестабильна внутри Codex sandbox из-за доступа к `user://`.
- Для автоматической проверки агентом использовать PowerShell contract-тесты.
  Не запускать Godot headless повторно; runtime проверять вручную в обычном редакторе.
- Steam headless editor process может зависнуть, если тот же проект уже открыт
  в GUI. Это ограничение CLI-проверки, а не runtime-ошибка проекта.
- Временный fallback при регрессии: Godot 4.6.

## Addons

| Addon | Версия | Статус 4.7.1 |
| --- | --- | --- |
| Jigglebone | 2.0.1 | Enabled, загружается. |
| Phantom Camera | 0.9.4.2 | Enabled; применён локальный 4.7 lifecycle patch для Viewfinder manager. |
| Proton Scatter | 4.0 | Enabled; применён локальный 4.7 compatibility patch в `src/scatter.gd`. |
| Script Spliter | 0.4-DEV-3.2 | Enabled, загружается. |
| SimpleGrassTextured | 2.0.8 | Enabled, загружается; singleton подключён autoload. |
| InputMapperPresetLoader | 1.0.0 | Disabled; несовпадение регистра пути исправлено для case-sensitive export. |
| Zylann HTerrain | локальная копия | Disabled. |

## Proton Scatter patch

Godot 4.7.1 выдавал:

```text
Parse Error: Not all code paths return a value.
res://addons/proton_scatter/src/scatter.gd:241
```

Причина: `_get(property)` не возвращал `Variant` для неизвестного свойства. Добавлен явный `return null`. После изменения исходная parse error и каскадные compile errors исчезли.

## Phantom Camera patch

При переходе от Main Menu к `res://levels/components/BattleArena/BattleArena.tscn` Viewfinder обращался к уже освобождённому `PhantomCameraManager`. `Engine.has_singleton()` возвращал true, но объект был невалиден. В результате сначала возникали null-instance errors, затем Godot 4.7.1 падал с `signal 11`.

В `scripts/panel/viewfinder/viewfinder.gd` добавлена проверка `is_instance_valid()` перед чтением manager и перед подключением его сигналов. Это точечный backport lifecycle guard из актуальной ветки Phantom Camera.

Regression-test:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .codex/tests/battle-arena-editor.tests.ps1
```

## Save-system verification

Основная автоматическая проверка для Codex:

```powershell
powershell -ExecutionPolicy Bypass `
  -File .codex/tests/save-system-contract.tests.ps1
```

Она не запускает Steam Godot и не зависит от sandbox-доступа к `user://`.

Runtime-проверка ниже предназначена только для ручного запуска вне Codex sandbox,
когда закрыт GUI-редактор:

Runtime-модель, versioned JSON, восстановление битого сейва и загрузка новых
сцен проверяются:

```powershell
& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' `
  --headless --path 'C:\GodotProjects\zeldaclone' `
  --script res://.codex/tests/save_system_runtime_test.gd

```

При `--script` Steam-сборка может вывести сообщения об ObjectDB/resources при
завершении из-за загруженных autoload-плагинов. Сам тест должен вывести
`PASS: PlayerData runtime progression`.
