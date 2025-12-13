extends Node

const MAX_ATTACKERS = 1 # !!! Временно поставь 1, чтобы проверить наверняка !!!

var current_attackers: Array[Enemy] = []

func request_attack_token(enemy: Enemy) -> bool:
	if enemy in current_attackers:
		return true
		
	if current_attackers.size() < MAX_ATTACKERS:
		current_attackers.append(enemy)
		_show_debug_indicator(enemy, true) # Показываем метку
		print("[AI] Token GRANTED: ", enemy.name)
		return true
		
	return false

func return_attack_token(enemy: Enemy) -> void:
	if enemy in current_attackers:
		current_attackers.erase(enemy)
		_show_debug_indicator(enemy, false) # Скрываем метку
		print("[AI] Token RETURNED: ", enemy.name)

# --- DEBUG VISUALIZATION ---
func _show_debug_indicator(enemy: Enemy, is_active: bool):
	# Пытаемся найти Label3D над головой врага (если есть) или красим его
	# Самый простой способ: менять цвет материала временно (если это не HitFlash)
	# Или просто выводить в консоль (уже сделано выше).
	
	# Вариант с Label3D (создай его программно):
	var label_name = "DebugAttackToken"
	var label = enemy.get_node_or_null(label_name)
	
	if is_active:
		if not label:
			label = Label3D.new()
			label.name = label_name
			label.text = "ATTACKING!"
			label.modulate = Color.RED
			label.font_size = 26
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.position = Vector3(0, 2.5, 0)
			enemy.add_child(label)
	else:
		if label:
			label.queue_free()
