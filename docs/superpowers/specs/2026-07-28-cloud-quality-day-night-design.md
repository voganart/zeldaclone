# Cloud Quality and Day/Night Design

## Goal

Сделать три уровня качества облаков без сброса времени суток и настроек неба:

- `LOW`: noise-clouds внутри `WorldEnvironment`;
- `MEDIUM`: плоские `BillboardMesh`;
- `HIGH`: объёмные raymarch-clouds.

Одинаковая смена дня и ночи должна работать в `Level_01.tscn`, `test_level/level.tscn` и будущих уровнях.

## Current Problems

1. `BillboardMesh` в `assets/shaders/Cloud_volumetric/cloud.tscn` имеет `visible = false`.
2. Billboard shader начинает показывать облако только после `fade_distance = 300`, но облака создаются примерно на расстоянии 125–175, поэтому итоговая alpha равна нулю.
3. `CloudManager` при старте удаляет сохранённые в сцене облака и создаёт 50 новых в один кадр.
4. `GraphicsManager` меняет только постэффекты и LOD, но не сообщает EnvironmentSystem выбранный тип облаков.
5. `DayNightCycle.gd` обновляет цвета объёмного материала, но noise-clouds используют другие uniform-имена:
   - volumetric/billboard: `color_light`, `color_shadow`;
   - sky noise: `cloud_edge_color`, `cloud_core_color`.
6. `test_level/level.tscn` содержит собственный `WorldEnvironment` с `clouds.gdshader`, но не использует общий day/night controller.

## Architecture

### GraphicsManager

Каждый preset получает поле `cloud_mode`:

- LOW → `SKY_NOISE`;
- MEDIUM → `BILLBOARD`;
- HIGH → `VOLUMETRIC`.

`quality_changed` продолжает передавать весь Dictionary. EnvironmentSystem читает `cloud_mode`, поэтому существующие подписчики не ломаются.

### CloudManager

`CloudManager` становится единственным владельцем mesh-clouds и предоставляет:

```gdscript
enum CloudMode { SKY_NOISE, BILLBOARD, VOLUMETRIC }

func set_cloud_mode(mode: CloudMode) -> void
```

Поведение:

- `SKY_NOISE`: контейнер mesh-clouds скрыт, `WorldEnvironment` использует sky material с `clouds.gdshader`;
- `BILLBOARD`: у каждого cloud instance скрыт `VolumetricMesh`, показан `BillboardMesh`;
- `VOLUMETRIC`: показан `VolumetricMesh`, скрыт `BillboardMesh`.

Облака создаются один раз. Повторное переключение качества только меняет видимость и sky material, не пересоздаёт ноды.

Сохранённые editor-generated children не должны одновременно удаляться и пересоздаваться на старте. Runtime использует уже существующие children; генерация выполняется только если children отсутствуют.

### Sky Materials

EnvironmentSystem хранит две ссылки:

- базовый sky material без noise-clouds;
- sky material с `clouds.gdshader`.

При смене режима меняется только `Sky.sky_material`. Сам объект `Environment`, текущее время, свет, post-processing и пользовательские параметры не пересоздаются.

Параметры noise material настраиваются в `.tscn/.tres`, а не создаются заново кодом. Это сохраняет художественные настройки из `test_level/level.tscn`.

### DayNightCycle

`DayNightCycle` обновляет активный sky material по capability, а не по имени конкретного shader:

- если существует `sky_top_color`, обновляет верх неба;
- если существует `sky_horizon_color`, обновляет горизонт;
- если существует `sky_bottom_color`, обновляет низ;
- если существуют `stars_intensity`, обновляет звёзды;
- если существуют `cloud_edge_color` и `cloud_core_color`, обновляет noise-clouds;
- отдельно обновляет `color_light` и `color_shadow` общего mesh-cloud material.

Для noise-clouds:

- `cloud_edge_color` получает дневной/ночной `cloud_light_color`;
- `cloud_core_color` получает `cloud_shadow_color`.

Это не меняет скорость, scale, cutoff, fuzziness и noise textures при ходе времени.

### test_level/level.tscn

Уровень получает `DayNightCycle` как controller поверх уже существующих:

- `WorldEnvironment`;
- `DirectionalLight3D`;
- sky material с `clouds.gdshader`.

Полный `EnvironmentSystem` с 50 mesh-clouds туда не добавляется. Поэтому визуальная настройка уровня сохраняется, но солнце, луна, небо и noise-clouds начинают реагировать на `time_of_day`.

## Error Handling

- Отсутствующий `WorldEnvironment`, Sky или material не приводит к ошибке.
- Если shader не содержит конкретный uniform, параметр не записывается.
- Если у cloud instance отсутствует одна из mesh-нод, переключается доступная нода и выводится одно предупреждение.
- При смене сцены новый EnvironmentSystem применяет текущее качество после входа в дерево.

## Testing

Автоматические Godot tests проверяют:

1. LOW скрывает обе mesh-ноды и активирует noise sky.
2. MEDIUM показывает только BillboardMesh.
3. HIGH показывает только VolumetricMesh.
4. Повторное переключение не меняет число cloud instances.
5. Day/night обновляет sky и оба набора cloud colors.
6. Неизвестный или отсутствующий uniform безопасно пропускается.
7. `test_level/level.tscn` загружается с day/night controller без добавления mesh-clouds.

Ручная проверка:

1. Запустить `Level_01.tscn`.
2. Переключить F1/F2/F3 и проверить три вида облаков.
3. Во время каждого режима изменить `time_of_day`.
4. Убедиться, что цвет неба и облаков меняется без скачка времени.
5. Запустить `test_level/level.tscn` и проверить движение времени с noise-clouds.

## Out of Scope

- Финальный художественный тюнинг формы и цвета billboard-clouds.
- Android export preset.
- Audio/VFX pooling.
- Переработка остальных post-processing presets.
