extends Node2D

@export var hand_path: NodePath
@export var deck_visual_path: NodePath
@export var card_scene: PackedScene
@export var starting_deck_size: int = 20

var deck: Array[int] = []
var discard: Array[int] = []
var _is_dealing: bool = false

@onready var hand: Control = get_node(hand_path) as Control
@onready var deck_visual: Control = get_node(deck_visual_path) as Control

func _ready() -> void:
	_build_deck()
	_disable_deck_visual_interaction()
	print("[DECK] ready deck_count=", deck.size())

func _build_deck() -> void:
	deck.clear()
	discard.clear()
	for i in range(starting_deck_size):
		deck.append(0)
	deck.shuffle()
	print("[DECK] built+shuffled count=", deck.size())

func _disable_deck_visual_interaction() -> void:
	if deck_visual == null:
		return
	deck_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deck_visual.set_process(false)
	deck_visual.set_physics_process(false)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Draw"):
		deal_one()
	elif event.is_action_pressed("Discard"):
		discard_one()

func deal_one() -> void:
	if _is_dealing:
		print("[DECK] draw blocked: dealing")
		return
	if deck.is_empty():
		print("[DECK] empty")
		return
	if hand == null or deck_visual == null or card_scene == null:
		print("[DECK] missing refs hand/deck_visual/card_scene")
		return
	_is_dealing = true
	var id: int = int(deck.pop_back())
	var c := card_scene.instantiate() as Control
	if c == null:
		print("[DECK] instantiate failed")
		_is_dealing = false
		return
	if c.has_method("set_dealing"):
		c.set_dealing(true)
	hand.add_child(c)
	c.global_position = deck_visual.global_position
	c.rotation_degrees = 0.0
	c.set_meta("card_id", id)
	var count: int = hand.get_child_count()
	var index: int = count - 1
	var layout: Dictionary = hand.call("get_layout_for_index", index, count)
	var end_pos: Vector2 = layout.get("pos", Vector2.ZERO)
	var end_rot: float = float(layout.get("rot_deg", 0.0))
	var shift_tw_var = hand.call("layout_cards_animated", 0.22, c)
	var shift_tw: Tween = shift_tw_var as Tween
	var fly_tw := create_tween()
	fly_tw.set_ease(Tween.EASE_OUT)
	fly_tw.set_trans(Tween.TRANS_QUAD)
	var start_pos: Vector2 = c.position
	var mid_pos: Vector2 = (start_pos + end_pos) * 0.5 + Vector2(0.0, -120.0)
	fly_tw.tween_property(c, "position", mid_pos, 0.10)
	fly_tw.tween_property(c, "position", end_pos, 0.12)
	fly_tw.parallel().tween_property(c, "rotation_degrees", end_rot, 0.22)
	print("[DECK] deal id=", id, " deck_left=", deck.size(), " hand_count=", count)
	var pending := {"n": 1}
	if shift_tw != null:
		pending["n"] = 2
	var finish := func() -> void:
		pending["n"] = int(pending["n"]) - 1
		if int(pending["n"]) > 0:
			return
		if is_instance_valid(c) and c.has_method("set_dealing"):
			c.set_dealing(false)
		_is_dealing = false
		hand.call("update_cards")
		print("[DECK] deal_done hand_count=", hand.get_child_count())
	if shift_tw != null:
		shift_tw.finished.connect(finish)
	else:
		finish.call()
	fly_tw.finished.connect(finish)

func discard_one() -> void:
	if hand == null:
		return
	var count: int = hand.get_child_count()
	if count == 0:
		return
	var last := hand.get_child(count - 1) as Control
	if last == null:
		return
	var id: int = 0
	if last.has_meta("card_id"):
		id = int(last.get_meta("card_id"))
	discard.append(id)
	hand.remove_child(last)
	last.queue_free()
	hand.call("layout_cards_animated", 0.18, null)
	print("[DECK] discard id=", id, " discard_count=", discard.size(), " hand_count=", hand.get_child_count())
