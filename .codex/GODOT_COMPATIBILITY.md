# Совместимость Godot

Проверено: 2026-07-28.

## Engine

- Текущая версия: Godot `4.7.1.stable.steam.a13da4feb`.
- Предыдущая версия проекта: Godot `4.6`.
- `project.godot` уже мигрирован на feature tag `4.7`.
- Editor parse-check: проходит.
- GUI editor smoke-check: проходит.
- Main scene headless smoke-check: проходит.
- Временный fallback при регрессии: Godot 4.6.

## Addons

| Addon | Версия | Статус 4.7.1 |
| --- | --- | --- |
| Jigglebone | 2.0.1 | Enabled, загружается. |
| Phantom Camera | 0.9.4.2 | Enabled, загружается; manager подключён autoload через UID. |
| Proton Scatter | 4.0 | Enabled; применён локальный 4.7 compatibility patch в `src/scatter.gd`. |
| Script Spliter | 0.4-DEV-3.2 | Enabled, загружается. |
| SimpleGrassTextured | 2.0.8 | Enabled, загружается; singleton подключён autoload. |
| InputMapperPresetLoader | 1.0.0 | Disabled; внутри addon есть несовпадение регистра пути. |
| Zylann HTerrain | локальная копия | Disabled. |

## Proton Scatter patch

Godot 4.7.1 выдавал:

```text
Parse Error: Not all code paths return a value.
res://addons/proton_scatter/src/scatter.gd:241
```

Причина: `_get(property)` не возвращал `Variant` для неизвестного свойства. Добавлен явный `return null`. После изменения исходная parse error и каскадные compile errors исчезли.

## Известный portability-риск

`addons/InputMapperPresetLoader/InputMapperPresets.tscn` использует путь с другим регистром:

```text
res://addons/inputmapperpresetloader/InputMapperPresets.gd
```

Фактическая папка называется `addons/InputMapperPresetLoader`. На Windows это работает, но на case-sensitive export platform файл не откроется. Addon сейчас выключен, поэтому это не блокирует запуск.
