class_name CardPanel
extends CanvasLayer

# Shows cards over the arena, one after another. While a card is open nothing else takes
# input; confirming or a click closes it.

# The kinds of entity whose card has been shown since the game started.
static var seen: Dictionary[Script, bool] = {}

@onready var arena: Arena = get_parent()
@onready var swatch: ColorRect = %Swatch
@onready var title_label: Label = %TitleLabel
@onready var text_label: Label = %TextLabel

var queue: Array[Card] = []


func _ready() -> void:
	arena.ready.connect(introduce)
	show_next()


# Shows the card of every kind on the board that the player meets for the first time.
func introduce() -> void:
	var cards: Array[Card] = []
	for entity in arena.entities:
		var card := entity.card()
		if card and not seen.has(entity.get_script()):
			seen[entity.get_script()] = true
			cards.append(card)
	show_cards(cards)


func show_cards(cards: Array[Card]) -> void:
	var was_open := visible
	queue.append_array(cards)
	if not was_open:
		show_next()


# The next card in the queue, or nothing once it is empty.
func show_next() -> void:
	visible = not queue.is_empty()
	if visible:
		var card: Card = queue.pop_front()
		swatch.color = card.color
		title_label.text = card.title
		text_label.text = card.text


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed):
		show_next()
	get_viewport().set_input_as_handled()
