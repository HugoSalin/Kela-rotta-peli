class_name Motion
extends RefCounted

# How an entity animates. Only the view calls it, with the tween of the turn and the thing
# it draws for the entity. Another way of moving is a class that extends this one.

const BUMP := 0.3

var duration := 0.2


func play_move(tween: Tween, drawn: Object, to: Vector2) -> void:
	tween.tween_property(drawn, "position", to, duration)


# A short push toward the place it couldn't move to, and back.
func play_blocked(tween: Tween, drawn: Object, from: Vector2, toward: Vector2) -> void:
	tween.tween_property(drawn, "position", from + (toward - from) * BUMP, duration / 2)
	tween.tween_property(drawn, "position", from, duration / 2)
