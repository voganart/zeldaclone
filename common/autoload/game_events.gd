extends Node

## Сигнал вызывается при любом изменении здоровья игрока
signal player_health_changed(current_hp: float, max_hp: float)

## НОВЫЙ СИГНАЛ: Вызывается один раз при смерти игрока
signal player_died
