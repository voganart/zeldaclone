class_name State
extends Node

## Сигнал для перехода в другое состояние.
## state: ссылка на вызывающее состояние (обычно self)
## new_state_name: имя состояния, в которое нужно перейти (в нижнем регистре)
signal transitioned(state: State, new_state_name: String)

## Ссылка на сущность, которой управляет состояние (Игрок или Враг).
## Используем CharacterBody3D, так как и Player, и Enemy наследуются от него.
var entity: CharacterBody3D

## Ссылка на машину состояний (опционально, если нужно получать доступ к другим узлам)
var state_machine: StateMachine

## Вызывается при входе в состояние.
## Здесь запускаем анимации, сбрасываем таймеры и т.д.
func enter() -> void:
	pass

## Вызывается при выходе из состояния.
## Здесь очищаем данные, останавливаем таймеры и т.д.
func exit() -> void:
	pass

## Аналог _process(delta). Вызывается машиной состояний каждый кадр.
func update(_delta: float) -> void:
	pass

## Аналог _physics_process(delta). Вызывается машиной состояний каждый физический кадр.
func physics_update(_delta: float) -> void:
	pass
