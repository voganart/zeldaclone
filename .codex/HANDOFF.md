# Handoff: ZeldaClone

Актуально на 2026-07-29. Это первая точка входа для нового Codex-чата.

## Что читать

1. `.codex/HANDOFF.md` — текущее состояние и решения последнего цикла.
2. `.codex/ROADMAP.md` — согласованный backlog и следующий приоритет.
3. `.codex/PROJECT_MAP.md` — структура проекта и gameplay-навигация.
4. `.codex/GODOT_COMPATIBILITY.md` — версия Godot, патчи и правила проверки.
5. `.codex/TROUBLESHOOTING.md` — известные ошибки и подтверждённые причины.
6. `.codex/ENTRY_POINTS.md` — сцены, autoload и основные системы.

Для точного поиска файлов использовать `.codex/project-index.txt`.

## Текущее состояние Git

- Рабочая ветка: `codex/fix-roll-obstacle-motion`, создана по явному запросу
  пользователя без worktree.
- Пользовательские удаления ability-chest остаются незакоммиченными в
  `levels/Level_01.tscn`; не восстанавливать и не включать в Roll-fix commit.
- После пользовательского коммита `daa66aa` добавлены локальные F10 Debug
  Panel-коммиты;
  перед следующим push проверить актуальный `git status -sb`.
- По умолчанию работать напрямую в `master`; отдельную ветку или worktree
  создавать только по явному запросу пользователя.
- Облачные эксперименты сохранены отдельно в `codex/cloud-lod`.
- Не переносить из `codex/cloud-lod` distant-cloud streaming, impostor LOD,
  weather manager или cloud tuning без нового явного решения пользователя.

Последние основные коммиты:

- `0a1c0c7` — компактная collapsible F10-панель и локализация;
- `1f6ab91` — debug-only controller, F10 action и gameplay input gate;
- `8a68c6e` — runtime progression API для debug controls;
- `24e3a88` — implementation plan F10 Debug Panel;
- `0fff94f` — design F10 Debug Panel;
- `ca9f944` — live-состояния Double Jump, Air Dash и 3-hit combo в HUD;
- `861d01a` — контрактный тест новых состояний HUD;
- `5512d73` — временная белая иконка-ромб Vabo;
- `b6e0db7` — scene-контракт учитывает Godot `unique_id`;
- `e4ab2d2` — запрет нестабильных автоматических headless-проверок Godot;
- `cbfaed3` — модульная система сохранений через Memory Node;
- `44c3a41` — корневой transform `Level_01` возвращён в ноль, сохранена
  прозрачность `x-ray_mat.tres`;
- `b077939` — исправлены предупреждения совместимости Godot 4.7;
- `bf0cfb7` — noise облаков отвязан от движения игрока;
- `878c78b` — возвращён debug flight с регулировкой скорости колесом;
- `23ca820` — исправлен lifecycle Phantom Camera.

## Подтверждённые рабочие изменения

### Сохранения

Реализован один versioned JSON save slot через:

- `common/autoload/save_manager.gd`;
- `common/autoload/player_data.gd`;
- `common/persistence/persistent_state.gd`;
- `entities/interactive/MemoryNode/MemoryNode.tscn`.

Сохраняются:

- текущий уровень и активный checkpoint;
- Vabo на момент записи на диск;
- максимальное здоровье;
- способности;
- persistent ID завершённых одноразовых событий.

Правила:

- Memory Node полностью лечит, становится checkpoint и записывает snapshot;
- получение постоянной способности сразу вызывает autosave;
- завершённые одноразовые головоломки и постоянно открытые проходы сохраняются
  через уникальный `persistent_id`;
- враги, ящики, обычные ловушки и временные платформы после смерти
  перезапускаются;
- Vabo, собранные после последнего дискового сохранения, переживают смерть
  внутри текущей сессии, но теряются при выходе без нового save event;
- после смерти уровень перезагружается, игрок появляется у последнего
  Memory Node;
- без активного checkpoint используется `PlayerStart`.

В `Level_01` установлен первый Memory Node:

- checkpoint ID: `level_01_after_crates`;
- расположен после стартового участка с ящиками;
- сундуки способностей получили стабильные persistent ID.

Главное меню динамически показывает `Continue` или `New Game`.
Битый save не блокирует запуск и сбрасывается в новое прохождение.

Пользователь вручную подтвердил 2026-07-29:

- сохранение работает;
- загрузка сохранения работает;
- кнопка `Continue` работает.

Полный дизайн:
`docs/superpowers/specs/2026-07-29-memory-save-system-design.md`.

### Player Progress Feedback

- HUD показывает текущие Vabo под сердцами и обновляется через
  `PlayerData.vabo_changed`.
- Вместо текста `Vabo` используется временная белая иконка-ромб
  `assets/textures/ui/Vabo.png`.
- Положение счётчика настраивается в `UI/player_hud.tscn`:
  `HealthContainer/HealthStack/VaboOffset` → `margin_left`/`margin_top`;
  расстояние от сердец — `HealthStack` → `separation`.
- Справа снизу показываются только открытые способности; закрытые способности
  не оставляют пустых слотов.
- Roll сохраняет отображение зарядов; Ground Slam, Air Dash и 3-hit combo
  показывают круговую перезарядку.
- Double Jump становится серым после второго прыжка и снова белым после
  приземления.
- Air Dash после использования остаётся серым до приземления, даже если его
  короткий cooldown уже закончился.
- Для Double Jump, Air Dash и 3-hit combo добавлены временные белые PNG-иконки
  `128x128`; существующие Roll и Ground Slam не заменялись. Vabo также
  использует временную белую PNG-иконку `128x128`.
- Источник прогресса остаётся в `PlayerData`; HUD не хранит копию состояния.
- Gameplay cooldown и balance-параметры не менялись.

Полный дизайн:
`docs/superpowers/specs/2026-07-29-player-progress-feedback-design.md`.

### F10 Debug Panel

- `F10` открывает компактную левую панель шириной `320 px`; fullscreen
  затемнения нет.
- Панель доступна только в debug/editor build и не создаётся в release export.
- Игра не ставится на паузу, но управление персонажем и debug flight
  блокируются, пока панель открыта.
- При открытии мышь освобождается; camera input не может повторно захватить её
  кликом. После закрытия восстанавливается предыдущий mouse mode.
- Панель закрывается повторным `F10` или компактным крестиком в заголовке.
- Категории `Save`, `Player`, `Progression`, `Checkpoint` независимо
  сворачиваются стрелками.
- Реализованы: полный reset сейва с перезапуском уровня, лечение, reload уровня,
  точная установка Vabo, unlock/lock всех способностей и телепорт к активному
  Memory Node.
- Debug-изменения Vabo/способностей сами не вызывают autosave. Последующий
  обычный save event может записать текущее debug-состояние.
- Runtime object inspector и редактирование transform отложены на следующую
  итерацию панели.
- Пользователь вручную подтвердил 2026-07-29: панель открывается, действия
  работают, клики не возвращаются в gameplay, крестик корректно закрывает UI.

Полный дизайн:
`docs/superpowers/specs/2026-07-29-f10-debug-panel-design.md`.

### Debug flight

- `F7` — включить/выключить режим;
- `WASD` — движение относительно камеры;
- `Space` / `Ctrl` — вверх/вниз;
- `Shift` — ускорение;
- колесо вверх/вниз — изменить базовую скорость в диапазоне `5..200`;
- колесо меняет скорость только при активном flight mode;
- в полёте отключаются обычная гравитация, столкновения и fall/respawn logic.

### Облака

Оставлена простая текущая система volumetric clouds.

- Noise продолжает самостоятельно прокручиваться через `TIME * move_speed`,
  создавая эффект ветра.
- Noise больше не зависит от позиции или движения игрока/CloudManager.
- Дальние процедурные облака и streaming не входят в `master`, потому что
  сильно нагружали проект и визуально не устроили пользователя.

### Phantom Camera и Godot 4.7

- PhantomCameraManager не удаляется при промежуточном editor/plugin reload.
- Viewfinder проверяет валидность manager перед обращением к нему.
- Исправлены case-sensitive пути InputMapperPresetLoader.
- Исправлены typed property-list warnings и совместимость Proton Scatter.

## Правила автоматической проверки

Не запускать Steam Godot в headless-режиме из Codex sandbox. В этой среде
движок может падать с `signal 11` из-за доступа к `user://`; это уже
диагностированный артефакт окружения, а не gameplay regression.

Для автоматической проверки использовать PowerShell-тесты в `.codex/tests/`,
которые не запускают движок:

- `cloud-stable-noise.tests.ps1`;
- `godot-47-warning-regressions.tests.ps1`;
- `f10-debug-panel.tests.ps1`;
- `phantom-camera-lifecycle.tests.ps1`;
- `player-debug-flight.tests.ps1`;
- `player-progress-feedback.tests.ps1`;
- `save-system-contract.tests.ps1`;
- `update-project-index.tests.ps1`.

Runtime и визуальный smoke-test пользователь выполняет в обычном GUI Godot.

## Локализация

- Любой player-facing текст добавлять через
  `assets/translations/texts.csv`.
- Английский и русский варианты добавлять одновременно.
- Не хардкодить видимый UI-текст в `.gd` или `.tscn`.
- В save flow уже добавлены ключи `ui_continue`,
  `save_memory_anchored`, `save_data_invalid`.

## Согласованный игровой flow

Сохранения должны быть редкими и расставляться дизайнером в определённых
местах, а не происходить постоянно.

Цель:

- смерть наказывает повторным прохождением секции;
- враги и ящики возвращаются, позволяя дополнительно фармить Vabo;
- накопленные в сессии Vabo постепенно облегчают повторные попытки;
- уже решённые одноразовые головоломки не заставляют игрока повторять
  рутинную часть;
- постоянные способности сохраняются автоматически.

Не переусложнять полировку до завершения первого уровня. Сначала нужен
приятный полный gameplay loop `Level_01`, затем баланс checkpoint spacing,
Vabo и повторных боёв.

## Следующий приоритет

Согласованный порядок:

1. Выполнить GUI smoke-test исправленного Roll-препятствия в `Level_01`.
   Кодовый фикс убрал повторный `move_and_slide()` из Roll-state и скорость
   выталкивания `12`; passage motion теперь применяется один раз в общем physics
   loop со скоростью `5`, капсула уменьшается до движения и восстанавливается
   только после clearance-проверки полной стоячей капсулой.
   Проверить проход в обе стороны с `Debug > Visible Collision Shapes`.
   Автотест `.codex/tests/player-roll-obstacle.tests.ps1` проходит.
   `save-system-contract.tests.ps1` сейчас ожидаемо падает на удалённых
   пользователем ability-chest; к Roll-фиксу это не относится.
2. Продолжать собирать и довести до конца `Level_01`.
3. После появления полного игрового цикла настроить баланс Vabo,
   checkpoint spacing, врагов и повторных секций.
4. Позже — расширить Debug Panel runtime object inspector/transform controls.
5. Позже — Keeper of Memory, трата Vabo, health/ability upgrades и hub flow.

Подробный backlog находится в `.codex/ROADMAP.md`.

## Важные ограничения

- Не менять пользовательские сцены и материалы случайными editor-generated
  transform/ресурсными правками.
- Корневой `Level01` должен оставаться с identity transform
  (позиция `0, 0, 0`, без поворота и масштаба).
- `assets/_master/x-ray_mat.tres` сейчас намеренно имеет alpha `0.5375001`.
- Vendor-патчи внутри `addons/` сохранять и не заменять слепо обновлением
  плагина.
- Перед новыми облачными изменениями учитывать GPU-нагрузку и обязательно
  оставлять простой способ отключения.
