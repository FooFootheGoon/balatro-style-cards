extends Control

@export var card_scene: PackedScene
@export var y_curve: Curve
@export var rot_curve: Curve
@export var max_rot_deg: float = 10.0
@export var x_sep_px: float = 40.0
@export var y_min_px: float = -260.0
@export var y_max_px: float = 50.0
@export var card_size_px: Vector2 = Vector2(210, 294)

func draw_card() -> void:
	if card_scene == null:
		print("[HAND] card_scene is null")
		return
	var c := card_scene.instantiate()
	add_child(c)
	update_cards()
	print("[HAND] generated cards, count=", get_child_count())

func discard_card() -> void:
	if get_child_count() == 0:
		return
	var last := get_child(get_child_count() - 1)
	remove_child(last)
	last.queue_free()
	update_cards()
	print("[HAND] discarded, count=", get_child_count())

func update_cards() -> void:
	var cards: Array[Node] = get_children()
	var count: int = cards.size()
	if count == 0:
		return
	var hand_w: float = size.x
	var card_w: float = card_size_px.x
	var final_sep: float = x_sep_px
	var combined_w: float = (card_w * count) + (final_sep * (count - 1))
	if count > 1 and combined_w > hand_w:
		final_sep = (hand_w - (card_w * count)) / float(count - 1)
		combined_w = hand_w
	var offset_x: float = (hand_w - combined_w) * 0.5
	var dragged := MouseBrain.node_being_dragged
	for i in range(count):
		var t: float = 0.5
		if count > 1:
			t = float(i) / float(count - 1)
		var y_p: float = 0.0
		if y_curve != null:
			y_p = y_curve.sample(t)
		var r_norm: float = 0.5
		if rot_curve != null:
			r_norm = rot_curve.sample(t)
		var r_p: float = (r_norm * 2.0) - 1.0
		var rot_deg: float = max_rot_deg * r_p
		var x: float = offset_x + (float(i) * (card_w + final_sep))
		var base_y: float = size.y - card_size_px.y
		var y: float = base_y + y_min_px - (y_max_px * y_p)
		var c := cards[i] as Control
		if c == null:
			continue
		if c == dragged:
			continue
		c.position = Vector2(x, y)
		c.rotation_degrees = rot_deg
	print("[HAND] updated count=", count, " sep=", final_sep)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Draw"):
		draw_card()
	elif event.is_action_pressed("Discard"):
		discard_card()
