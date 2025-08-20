extends CharacterBody3D

@export var hp := 10
@export var knockback_time := 0.0
@export var gravity := 100
@export var knockback_strength = 2.0
@export var knockback_height = 5.0
func take_damage(amount, knockback_dir: Vector3):
	hp -= amount
	var final_knockback = knockback_dir.normalized() * knockback_strength
	final_knockback.y = knockback_height

	velocity = final_knockback
	knockback_time = 0.3

	if hp <= 0:
		queue_free()

func _physics_process(delta):
	# если в knockback, применяем гравитацию
	if knockback_time > 0:
		knockback_time -= delta
	else:
		velocity.x = 0
		velocity.z = 0
		velocity.y = 0  # стоим на земле
	velocity.y -= gravity * delta  # вручную гравитация
	move_and_slide()
