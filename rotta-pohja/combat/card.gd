class_name Card
extends RefCounted

# A short explanation for the player: of a kind of piece on the board, or of an ability.

var title: String
var text: String
# The color of the piece it explains, shown beside the title; transparent for none.
var color: Color


func _init(a_title: String, a_text: String, a_color := Color.TRANSPARENT) -> void:
	title = a_title
	text = a_text
	color = a_color
