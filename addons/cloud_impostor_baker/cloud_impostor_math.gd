@tool
class_name CloudImpostorMath
extends RefCounted


static func grid_to_lower_hemisphere(frame: Vector2i, frame_count: int) -> Vector3:
	var safe_count := maxi(frame_count, 2)
	var coord := Vector2(frame) / float(safe_count - 1)
	var position := Vector3(
		coord.x - coord.y,
		0.0,
		-1.0 + coord.x + coord.y
	)
	position.y = -(1.0 - absf(position.x) - absf(position.z))
	return position.normalized()


static func camera_up_for(direction: Vector3) -> Vector3:
	if absf(direction.dot(Vector3.UP)) > 0.999:
		return Vector3.BACK
	return Vector3.UP


static func atlas_rect(frame: Vector2i, tile_size: int) -> Rect2i:
	return Rect2i(frame * tile_size, Vector2i(tile_size, tile_size))
