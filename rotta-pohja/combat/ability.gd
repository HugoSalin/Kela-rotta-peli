class_name Ability
extends RefCounted

# Something the player can do on a turn, chosen with a number key.

var title: String
# Turns to wait after using it.
var cooldown: int
var turns_until_ready := 0
# One entry per cell the player picks, in order: how near and how far from the player it
# may be, and what the player is asked for.
var min_reaches: Array[int]
var reaches: Array[int]
var prompts: Array[String]
# It goes in one of the six straight directions, so its picks lie on those lines.
var straight: bool
# (picked: Array[Vector2i], cell: Vector2i) -> bool: may `cell` be the next pick?
var can_pick: Callable
# A first pick that this other ability takes goes on as that ability, while it is ready.
var hands_over_to: Ability
# (picked: Array[Vector2i]): does it, once every cell is picked.
var use: Callable


func _init(a_title: String, a_cooldown: int, a_min_reaches: Array[int], a_reaches: Array[int], a_prompts: Array[String], a_can_pick: Callable, a_use: Callable, a_straight := false, a_hands_over_to: Ability = null) -> void:
	title = a_title
	cooldown = a_cooldown
	min_reaches = a_min_reaches
	reaches = a_reaches
	prompts = a_prompts
	can_pick = a_can_pick
	use = a_use
	straight = a_straight
	hands_over_to = a_hands_over_to
