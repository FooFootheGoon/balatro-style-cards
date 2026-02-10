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

func get_layout_for_index(index: int, count: int) -> Dictionary:
	var hand_w: float = size.x
	var card_w: float = card_size_px.x
	var final_sep: float = x_sep_px
	var combined_w: float = (card_w * count) + (final_sep * (count - 1))
	if count > 1 and combined_w > hand_w:
		final_sep = (hand_w - (card_w * count)) / float(count - 1)
		combined_w = hand_w
	var offset_x: float = (hand_w - combined_w) * 0.5
	var t: float = 0.5
	if count > 1:
		t = float(index) / float(count - 1)
	var y_p: float = 0.0
	if y_curve != null:
		y_p = y_curve.sample(t)
	var r_p: float = 0.0
	if rot_curve != null:
		r_p = rot_curve.sample(t)
	var x: float = offset_x + (float(index) * (card_w + final_sep))
	var y: float = y_min_px - (y_max_px * y_p)
	var rot_deg: float = max_rot_deg * r_p
	return {"pos": Vector2(x, y), "rot_deg": rot_deg, "sep": final_sep}

func layout_cards_animated(duration: float = 0.22, skip: Control = null) -> Tween:
	var cards: Array[Node] = get_children()
	var count: int = cards.size()
	if count == 0:
		return null
	var dragged := MouseBrain.node_being_dragged
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_QUAD)
	for i in range(count):
		var c := cards[i] as Control
		if c == null:
			continue
		if c == dragged:
			continue
		if skip != null and c == skip:
			continue
		var layout := get_layout_for_index(i, count)
		tw.parallel().tween_property(c, "position", layout["pos"], duration)
		tw.parallel().tween_property(c, "rotation_degrees", layout["rot_deg"], duration)
	print("[HAND] tween_layout count=", count, " sep=", get_layout_for_index(0, count)["sep"], " dur=", duration)
	return tw

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
	#var offset_x: float = (hand_w - combined_w) * 0.5 # I've accidentally deleted the use case for this. 
	var dragged := MouseBrain.node_being_dragged
	for i in range(count):
		var c := cards[i] as Control
		if c == null:
			continue
		if c == dragged:
			continue
		var layout := get_layout_for_index(i, count)
		c.position = layout["pos"]
		c.rotation_degrees = layout["rot_deg"]
		print("[HAND] updated count=", count, " sep=", get_layout_for_index(0, count)["sep"])
