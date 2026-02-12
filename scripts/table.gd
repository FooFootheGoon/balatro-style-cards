extends Node2D

@export var hand_path: NodePath
@export var deck_visual_path: NodePath
@export var card_scene: PackedScene
@export var starting_deck_size: int = 20
@export var anchor_path: NodePath
@export var parallax_enabled: bool = true
@export var parallax_max_px: float = 10.0
@export var parallax_lerp_speed: float = 7.0
@onready var anchor: Node2D = get_node_or_null(anchor_path) as Node2D

var _anchor_base_pos: Vector2 = Vector2.ZERO
var _anchor_base_set: bool = false
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
	if InputMap.has_action("DrawMany") and event.is_action_pressed("DrawMany"):
		deal_cards(5)
		get_viewport().set_input_as_handled()
		return
	if InputMap.has_action("Draw") and event.is_action_pressed("Draw"):
		deal_one()
		get_viewport().set_input_as_handled()
		return
	if InputMap.has_action("Discard") and event.is_action_pressed("Discard"):
		discard_one()
		get_viewport().set_input_as_handled()
		return

func _process(delta: float) -> void:
	if not parallax_enabled:
		return
	if anchor == null:
		return
	if not _anchor_base_set:
		_anchor_base_pos = anchor.position
		_anchor_base_set = true
		print("[PARALLAX] base=", _anchor_base_pos)
	var vp := get_viewport()
	var rect := vp.get_visible_rect()
	var center: Vector2 = rect.size * 0.5
	if center.x <= 0.0 or center.y <= 0.0:
		return
	var mouse: Vector2 = vp.get_mouse_position()
	var norm: Vector2 = (mouse - center) / center
	norm.x = clampf(norm.x, -1.0, 1.0)
	norm.y = clampf(norm.y, -1.0, 1.0)
	var strength: float = parallax_max_px * 0.6
	var target: Vector2 = _anchor_base_pos + (norm * strength)
	anchor.position = anchor.position.lerp(target, parallax_lerp_speed * delta)

func deal_one() -> void:
	if _is_dealing:
		print("[DRAW_SLEEK] blocked: dealing")
		return
	if deck.is_empty():
		print("[DRAW_SLEEK] blocked: deck empty")
		return
	if hand == null or deck_visual == null or card_scene == null:
		print("[DRAW_SLEEK] blocked: missing refs")
		return
	_is_dealing = true
	var id: int = int(deck.pop_back())
	var c := card_scene.instantiate() as Control
	if c == null:
		print("[DRAW_SLEEK] instantiate failed")
		_is_dealing = false
		return
	if c.has_method("set_dealing"):
		c.set_dealing(true)
	hand.add_child(c)
	var deck_global: Vector2 = deck_visual.get_global_transform_with_canvas().origin
	var hand_inv: Transform2D = hand.get_global_transform_with_canvas().affine_inverse()
	var start_pos: Vector2 = hand_inv * deck_global
	c.position = start_pos
	c.rotation_degrees = 0.0
	c.scale = Vector2.ONE * 0.90
	c.z_index = 1000
	c.set_meta("card_id", id)
	var count: int = hand.get_child_count()
	var index: int = count - 1
	var layout: Dictionary = hand.call("get_layout_for_index", index, count)
	var end_pos: Vector2 = layout.get("pos", Vector2.ZERO)
	var end_rot: float = float(layout.get("rot_deg", 0.0))
	var dur: float = 0.20 + float(index) * 0.03
	hand.call("layout_cards_animated", dur, c)
	var dir: Vector2 = end_pos - start_pos
	var side: float = clampf(dir.x * 0.10, -55.0, 55.0)
	var lift: float = clampf(150.0 + absf(dir.x) * 0.08, 150.0, 210.0)
	var mid_pos: Vector2 = (start_pos + end_pos) * 0.5 + Vector2(side, -lift)
	var over_pos: Vector2 = end_pos + Vector2(0.0, -10.0)
	var mid_rot: float = end_rot * 0.35
	var over_rot: float = end_rot * 1.10
	var d1: float = dur * 0.55
	var d2: float = dur * 0.25
	var d3: float = maxf(0.07, dur - d1 - d2)
	var tw := c.create_tween()
	var p1 := tw.tween_property(c, "position", mid_pos, d1)
	p1.set_trans(Tween.TRANS_QUINT)
	p1.set_ease(Tween.EASE_OUT)
	var r1 := tw.parallel().tween_property(c, "rotation_degrees", mid_rot, d1)
	r1.set_trans(Tween.TRANS_QUINT)
	r1.set_ease(Tween.EASE_OUT)
	var s1 := tw.parallel().tween_property(c, "scale", Vector2(1.02, 1.00), d1)
	s1.set_trans(Tween.TRANS_QUAD)
	s1.set_ease(Tween.EASE_OUT)
	var p2 := tw.tween_property(c, "position", over_pos, d2)
	p2.set_trans(Tween.TRANS_CUBIC)
	p2.set_ease(Tween.EASE_OUT)
	var r2 := tw.parallel().tween_property(c, "rotation_degrees", over_rot, d2)
	r2.set_trans(Tween.TRANS_CUBIC)
	r2.set_ease(Tween.EASE_OUT)
	var s2 := tw.parallel().tween_property(c, "scale", Vector2(1.05, 0.98), d2)
	s2.set_trans(Tween.TRANS_CUBIC)
	s2.set_ease(Tween.EASE_OUT)
	var p3 := tw.tween_property(c, "position", end_pos, d3)
	p3.set_trans(Tween.TRANS_QUAD)
	p3.set_ease(Tween.EASE_OUT)
	var r3 := tw.parallel().tween_property(c, "rotation_degrees", end_rot, d3)
	r3.set_trans(Tween.TRANS_QUAD)
	r3.set_ease(Tween.EASE_OUT)
	var s3 := tw.parallel().tween_property(c, "scale", Vector2.ONE, d3)
	s3.set_trans(Tween.TRANS_BACK)
	s3.set_ease(Tween.EASE_OUT)
	print("[DRAW_SLEEK] start id=", id, " deck_left=", deck.size(), " hand_now=", count, " dur=", dur)
	var timeout_ms: int = int((dur + 0.25) * 1000.0)
	var t0: int = Time.get_ticks_msec()
	while is_instance_valid(tw) and tw.is_running() and (Time.get_ticks_msec() - t0) < timeout_ms:
		await get_tree().process_frame
	if is_instance_valid(tw) and tw.is_running():
		print("[DRAW_SLEEK] tween timeout, snapping id=", id)
		tw.kill()
	if is_instance_valid(c):
		c.position = end_pos
		c.rotation_degrees = end_rot
		c.scale = Vector2.ONE
		c.z_index = 0
		if c.has_method("set_dealing"):
			c.set_dealing(false)
	_is_dealing = false

func deal_cards(amount: int) -> void:
	if _is_dealing:
		print("[DRAW_BATCH] blocked: dealing")
		return
	if deck.is_empty():
		print("[DRAW_BATCH] blocked: deck empty")
		return
	if hand == null or deck_visual == null or card_scene == null:
		print("[DRAW_BATCH] blocked: missing refs")
		return
	var n: int = mini(amount, deck.size())
	if n <= 0:
		print("[DRAW_BATCH] blocked: n<=0")
		return
	_is_dealing = true
	var existing: Array[Control] = []
	for ch in hand.get_children():
		var cc := ch as Control
		if cc != null:
			existing.append(cc)
	var start_count: int = existing.size()
	var final_count: int = start_count + n
	var deck_global: Vector2 = deck_visual.get_global_transform_with_canvas().origin
	var hand_inv: Transform2D = hand.get_global_transform_with_canvas().affine_inverse()
	var start_pos: Vector2 = hand_inv * deck_global
	var shift_dur: float = 0.18
	for i in range(start_count):
		var ec: Control = existing[i]
		var lay_e: Dictionary = hand.call("get_layout_for_index", i, final_count)
		var end_e_pos: Vector2 = lay_e.get("pos", ec.position)
		var end_e_rot: float = float(lay_e.get("rot_deg", ec.rotation_degrees))
		var etw := ec.create_tween()
		var ep := etw.tween_property(ec, "position", end_e_pos, shift_dur)
		ep.set_trans(Tween.TRANS_QUAD)
		ep.set_ease(Tween.EASE_OUT)
		var er := etw.parallel().tween_property(ec, "rotation_degrees", end_e_rot, shift_dur)
		er.set_trans(Tween.TRANS_QUAD)
		er.set_ease(Tween.EASE_OUT)
	var new_cards: Array[Control] = []
	var base_delay: float = 0.045
	var base_dur: float = 0.22
	var dur_step: float = 0.04
	var max_end_s: float = 0.0
	for i in range(n):
		var id: int = int(deck.pop_back())
		var c := card_scene.instantiate() as Control
		if c == null:
			print("[DRAW_BATCH] instantiate failed at i=", i)
			continue
		if c.has_method("set_dealing"):
			c.set_dealing(true)
		hand.add_child(c)
		c.position = start_pos
		c.rotation_degrees = 0.0
		c.scale = Vector2.ONE * 0.90
		c.z_index = 1000 + i
		c.set_meta("card_id", id)
		new_cards.append(c)
		var idx: int = start_count + i
		var lay: Dictionary = hand.call("get_layout_for_index", idx, final_count)
		var end_pos: Vector2 = lay.get("pos", Vector2.ZERO)
		var end_rot: float = float(lay.get("rot_deg", 0.0))
		var delay: float = float(i) * base_delay
		var dur: float = base_dur + float(i) * dur_step
		var dir: Vector2 = end_pos - start_pos
		var side: float = clampf(dir.x * 0.10, -55.0, 55.0)
		var lift: float = clampf(160.0 + absf(dir.x) * 0.08, 160.0, 230.0)
		var mid_pos: Vector2 = (start_pos + end_pos) * 0.5 + Vector2(side, -lift)
		var over_pos: Vector2 = end_pos + Vector2(0.0, -10.0)
		var d1: float = dur * 0.55
		var d2: float = dur * 0.25
		var d3: float = maxf(0.07, dur - d1 - d2)
		var mid_rot: float = end_rot * 0.35
		var over_rot: float = end_rot * 1.10
		var tw := c.create_tween()
		var p1 := tw.tween_property(c, "position", mid_pos, d1)
		p1.set_delay(delay)
		p1.set_trans(Tween.TRANS_QUINT)
		p1.set_ease(Tween.EASE_OUT)
		var r1 := tw.parallel().tween_property(c, "rotation_degrees", mid_rot, d1)
		r1.set_delay(delay)
		r1.set_trans(Tween.TRANS_QUINT)
		r1.set_ease(Tween.EASE_OUT)
		var s1 := tw.parallel().tween_property(c, "scale", Vector2(1.02, 1.00), d1)
		s1.set_delay(delay)
		s1.set_trans(Tween.TRANS_QUAD)
		s1.set_ease(Tween.EASE_OUT)
		var p2 := tw.tween_property(c, "position", over_pos, d2)
		p2.set_trans(Tween.TRANS_CUBIC)
		p2.set_ease(Tween.EASE_OUT)
		var r2 := tw.parallel().tween_property(c, "rotation_degrees", over_rot, d2)
		r2.set_trans(Tween.TRANS_CUBIC)
		r2.set_ease(Tween.EASE_OUT)
		var s2 := tw.parallel().tween_property(c, "scale", Vector2(1.05, 0.98), d2)
		s2.set_trans(Tween.TRANS_CUBIC)
		s2.set_ease(Tween.EASE_OUT)
		var p3 := tw.tween_property(c, "position", end_pos, d3)
		p3.set_trans(Tween.TRANS_QUAD)
		p3.set_ease(Tween.EASE_OUT)
		var r3 := tw.parallel().tween_property(c, "rotation_degrees", end_rot, d3)
		r3.set_trans(Tween.TRANS_QUAD)
		r3.set_ease(Tween.EASE_OUT)
		var s3 := tw.parallel().tween_property(c, "scale", Vector2.ONE, d3)
		s3.set_trans(Tween.TRANS_BACK)
		s3.set_ease(Tween.EASE_OUT)
		max_end_s = maxf(max_end_s, delay + dur + 0.20)
		print("[DRAW_BATCH_CARD] i=", i, " id=", id, " idx=", idx, " delay=", delay, " dur=", dur)
	print("[DRAW_BATCH] start n=", n, " start_count=", start_count, " final_count=", final_count, " deck_left=", deck.size())
	var t0: int = Time.get_ticks_msec()
	var wait_ms: int = int(max_end_s * 1000.0)
	while (Time.get_ticks_msec() - t0) < wait_ms:
		await get_tree().process_frame
	for i in range(new_cards.size()):
		var c2: Control = new_cards[i]
		if is_instance_valid(c2):
			c2.scale = Vector2.ONE
			c2.z_index = 0
			if c2.has_method("set_dealing"):
				c2.set_dealing(false)
	_is_dealing = false
	hand.call("update_cards")
	print("[DRAW_BATCH] done hand_now=", hand.get_child_count(), " deck_left=", deck.size())

func discard_one() -> void:
	if _is_dealing:
		print("[DECK] discard blocked: dealing")
		return
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

func _settle_hand_after_deal() -> void:
	await get_tree().create_timer(0.26).timeout
	if hand != null and not _is_dealing:
		hand.call("update_cards")
		print("[DECK_FIX] settle_hand")
