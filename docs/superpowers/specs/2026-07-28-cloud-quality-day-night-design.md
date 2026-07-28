# Cloud Impostor LOD and Day/Night Design

## Goal

Сделать масштабируемую трёхступенчатую систему облаков без сброса времени суток и настроек неба:

- LOD0: объёмные raymarch-clouds рядом с камерой;
- LOD1: octahedral impostors на средней дистанции;
- LOD2: noise-clouds внутри `WorldEnvironment` на горизонте.

Одинаковая смена дня и ночи должна работать в `Level_01.tscn`, `test_level/level.tscn` и будущих уровнях.

Первый implementation slice создаёт и проверяет один cloud archetype. После визуального подтверждения тот же pipeline масштабируется на несколько форм и `MultiMesh`.

## Current Problems

1. Текущий `BillboardMesh` не является impostor объёмного облака: он строит отдельную круглую форму из 2D noise, поэтому силуэт, цвет и внутренняя светотень не совпадают с LOD0.
2. `BillboardMesh` в `assets/shaders/Cloud_volumetric/cloud.tscn` имеет `visible = false`.
3. Billboard shader начинает показывать облако только после `fade_distance = 300`, но облака создаются примерно на расстоянии 125–175, поэтому итоговая alpha равна нулю.
4. Одновременный alpha-blend объёмной и billboard-геометрии вызывает двойную яркость, проблемы transparent sorting и мерцание.
5. `CloudManager` при старте удаляет сохранённые в сцене облака и создаёт 50 новых в один кадр.
6. `GraphicsManager` меняет только постэффекты и LOD, но не сообщает EnvironmentSystem выбранный тип облаков.
7. `DayNightCycle.gd` обновляет цвета объёмного материала, но noise-clouds используют другие uniform-имена:
   - volumetric/billboard: `color_light`, `color_shadow`;
   - sky noise: `cloud_edge_color`, `cloud_core_color`.
8. `test_level/level.tscn` содержит собственный `WorldEnvironment` с `clouds.gdshader`, но не использует общий day/night controller.
9. Форма LOD0 изменяется через `TIME`, поэтому статически запечённый impostor не может совпадать с ней при неограниченной внутренней деформации.

## Architecture

### GraphicsManager

Каждый preset получает поля `cloud_lod_policy` и точные дистанции перехода:

- LOW → только `SKY_NOISE`;
- MEDIUM → `IMPOSTOR` + `SKY_NOISE`;
- HIGH → `VOLUMETRIC` + `IMPOSTOR` + `SKY_NOISE`.

Начальные дистанции прототипа:

- LOD0 полностью видим до 120 м;
- переход LOD0 → LOD1 проходит от 120 до 180 м;
- LOD1 полностью видим от 180 до 450 м;
- переход LOD1 → LOD2 проходит от 400 до 500 м.

Значения экспортируются и подлежат настройке после визуального теста. Переключение обратно использует hysteresis 10 м, чтобы LOD не прыгал на границе.

`quality_changed` продолжает передавать весь Dictionary. EnvironmentSystem читает cloud policy, поэтому существующие подписчики не ломаются.

### Cloud Archetype and Impostor Bake

Один archetype состоит из:

- исходного объёмного box mesh и `cloud_volumetric.gdshader`;
- octahedral impostor atlas;
- depth atlas;
- metadata: bounds, pivot, frame grid и scale;
- общего набора day/night цветов.

Для прототипа используется hemispherical atlas: облака в основном видны сбоку и снизу, полный сферический обзор не нужен. Целевой grid — 8×8; разрешение atlas — 2048×2048. Эти значения проверяются визуально и могут быть уменьшены для mobile.

В atlas запекаются форма, alpha/transmittance и depth, но не финальный цвет времени суток. Impostor shader получает `color_light` и `color_shadow` в runtime, поэтому рассвет, день и ночь остаются синхронными с LOD0.

Плагин `Godot-Octahedral-Impostors` рассматривается как reference и возможный editor baker. Он не добавляется в production runtime до проверки совместимости с Godot 4.7.1. Если его baker несовместим, минимальный project-local baker создаётся на `SubViewport` и выполняется только в редакторе.

### Cloud LOD Controller

Каждый близкий cloud instance имеет LOD0 и LOD1 с общим controller. Controller:

- вычисляет distance squared с ограниченной частотой, а не каждый кадр;
- выбирает разрешённые LOD согласно quality policy;
- передаёт обоим shader единый `lod_fade`;
- не создаёт и не удаляет ноды при переходе;
- фиксирует внутреннюю фазу формы LOD0 в зоне перехода, чтобы силуэт не уплывал относительно impostor;
- после завершения перехода полностью отключает process и visibility неактивного LOD.

Для прототипа применяется один controller на одну форму. После проверки LOD1 переносится в bucketed `MultiMesh`: одинаковые archetypes и одинаковый LOD bucket рисуются совместно.

Сохранённые editor-generated children не должны одновременно удаляться и пересоздаваться на старте. Runtime использует уже существующие children; генерация выполняется только если children отсутствуют.

### Seamless Crossfade

Обычный alpha fade не используется как основной переход, потому что два полупрозрачных слоя одновременно дают неверную яркость и нестабильный sorting.

LOD0 и LOD1 используют один стабильный screen-space dither pattern с комплементарными условиями:

- LOD0 сохраняет пиксель, когда pattern больше `lod_fade`;
- LOD1 сохраняет пиксель, когда pattern меньше либо равен `lod_fade`.

Таким образом, один LOD отдаёт пиксели второму без двойного наложения. Pattern привязан к экранным координатам и не использует `TIME`, чтобы не создавать temporal flicker.

Impostor shader:

- выбирает ближайшие octahedral frames по направлению камеры;
- смешивает frames с использованием depth;
- восстанавливает правильный pivot и projected bounds;
- использует premultiplied alpha;
- получает те же `color_light`, `color_shadow` и exposure, что LOD0.

### Sky Materials and LOD2

EnvironmentSystem хранит две ссылки:

- базовый sky material без noise-clouds;
- sky material с `clouds.gdshader`.

При смене policy меняется только `Sky.sky_material` и видимость разрешённых cloud LOD. Сам объект `Environment`, текущее время, свет, post-processing и пользовательские параметры не пересоздаются.

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
- Если у cloud archetype отсутствует atlas или metadata, controller оставляет LOD0 активным и выводит одно предупреждение.
- Если LOW запрещает LOD0, а atlas отсутствует, controller переключается на LOD2.
- При смене сцены новый EnvironmentSystem применяет текущее качество после входа в дерево.

## Testing

Автоматические Godot tests проверяют:

1. LOW скрывает LOD0/LOD1 и активирует noise sky.
2. MEDIUM запрещает LOD0, но разрешает impostor и noise sky.
3. HIGH разрешает все три LOD.
4. В transition band `lod_fade` меняется монотонно от 0 до 1.
5. Hysteresis не позволяет состоянию дрожать около одной дистанции.
6. Комплементарные dither-условия не показывают оба LOD в одном пикселе.
7. Повторное переключение не меняет число cloud instances.
8. Day/night обновляет sky, volumetric и impostor colors.
9. Неизвестный или отсутствующий uniform безопасно пропускается.
10. `test_level/level.tscn` загружается с day/night controller без добавления mesh-clouds.

Ручная проверка:

1. Запустить `Level_01.tscn`.
2. Медленно провести камеру через диапазон 100–200 м и проверить отсутствие pop, двойной яркости и flicker.
3. Обойти облако по дуге во время LOD1 и проверить blending между atlas frames.
4. Переключить F1/F2/F3 и проверить разрешённые LOD.
5. Во время каждого режима изменить `time_of_day`.
6. Убедиться, что цвет неба и облаков меняется без скачка времени.
7. Запустить `test_level/level.tscn` и проверить движение времени с noise-clouds.
8. Сравнить GPU frame time LOD0 и LOD1 при одинаковом количестве видимых облаков.

## Out of Scope

- Массовое производство дополнительных cloud archetypes до подтверждения прототипа.
- Runtime capture отдельной уникальной текстуры для каждого cloud instance.
- Обещание 10 000 одновременно видимых прозрачных clouds: фактический предел определяется fill-rate и overdraw на целевом телефоне.
- Android export preset.
- Audio/VFX pooling.
- Переработка остальных post-processing presets.
