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
@onready var hand: Control = get_node(hand_path) as Control
@onready var deck_visual: Control = get_node(deck_visual_path) as Control
@export var deck_def: DeckDefinition
@export var player_count: int = 2
@export var active_player_idx: int = 0
@export var reshuffle_discard_when_empty: bool = true
@export var reshuffle_uses_seed: bool = false
@export var rng_seed: int = 12345
@export var max_hand_size: int = 5

var deck: Array[int]:
	get:
		_ensure_players()
		return players[active_player_idx].draw
	set(value):
		_ensure_players()
		players[active_player_idx].draw = value
var discard: Array[int]:
	get:
		_ensure_players()
		return players[active_player_idx].discard
	set(value):
		_ensure_players()
		players[active_player_idx].discard = value

var players: Array[PlayerState] = []
var _anchor_base_pos: Vector2 = Vector2.ZERO
var _anchor_base_set: bool = false
var _is_dealing: bool = false

const _RANK_STR := ["A","2","3","4","5","6","7","8","9","10","J","Q","K"]
const _SUIT_STR := ["♣","♦","♥","♠"]

func _ready() -> void:
	if deck_def == null:
		deck_def = DeckDefinition.make_standard_52()
		print("[DECK_DEF] defaulted to standard_52")
	_build_deck()
	_disable_deck_visual_interaction()
	print("[DECK] ready players=", players.size(), " active=", active_player_idx, " deck_count=", deck.size())

func _build_deck() -> void:
	_ensure_players()
	if deck_def == null:
		deck_def = DeckDefinition.make_standard_52()
		print("[DECK_DEF] defaulted to standard_52")
	for pid in range(players.size()):
		var p: PlayerState = players[pid]
		p.draw.clear()
		p.hand.clear()
		p.discard.clear()
		var full: Array[int] = deck_def.build_full_deck_ids()
		full.shuffle()
		var n: int = clampi(starting_deck_size, 0, full.size())
		for i in range(n):
			p.draw.append(full[i])
	print("[DECK] built players=", players.size(), " active=", active_player_idx, " active_top5=", _debug_top_cards(5))

func _ensure_players() -> void:
	if not players.is_empty():
		active_player_idx = clampi(active_player_idx, 0, players.size() - 1)
		return
	if player_count <= 0:
		player_count = 1
	for pid in range(player_count):
		players.append(PlayerState.new(pid))
	active_player_idx = clampi(active_player_idx, 0, players.size() - 1)
	print("[PLAYERS] created count=", players.size(), " active=", active_player_idx)

func _active() -> PlayerState:
	_ensure_players()
	return players[active_player_idx]

func _disable_deck_visual_interaction() -> void:
	if deck_visual == null:
		return
	deck_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deck_visual.set_process(false)
	deck_visual.set_physics_process(false)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Draw"):
		deal_one()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("DrawMany"):
		deal_cards(5)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("Discard"):
		discard_one()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("SwitchPlayer1"):
		if players.size() <= 1:
			print("[SWITCH] blocked: players.size()=", players.size(), " (set player_count=2)")
			get_viewport().set_input_as_handled()
			return
		var next_idx: int = 1
		if active_player_idx == 1:
			next_idx = 0
		switch_active_player(next_idx)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("EndTurn"):
		discard_hand_to_max(active_player_idx, max_hand_size)
		if players.size() <= 1:
			print("[SWITCH] blocked: players.size()=", players.size(), " (set player_count=2)")
			get_viewport().set_input_as_handled()
			return
		var next_idx: int = 1
		if active_player_idx == 1:
			next_idx = 0
		switch_active_player(next_idx)
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
	var p: PlayerState = _active()
	if p.draw.is_empty():
		print("[DRAW_SLEEK] blocked: deck empty p=", p.owner_id)
		return
	if hand == null or deck_visual == null or card_scene == null:
		print("[DRAW_SLEEK] blocked: missing refs")
		return
	_is_dealing = true
	var id: int = int(p.draw.pop_back())
	p.hand.append(id)
	var c := card_scene.instantiate() as Control
	if c == null:
		print("[DRAW_SLEEK] instantiate failed")
		p.hand.pop_back()
		p.draw.append(id)
		_is_dealing = false
		return
	if c.has_method("set_dealing"):
		c.set_dealing(true)
	if deck_def != null and c.has_method("set_deck_def"):
		c.call("set_deck_def", deck_def)
	hand.add_child(c)
	var deck_global: Vector2 = deck_visual.get_global_transform_with_canvas().origin
	var hand_inv: Transform2D = hand.get_global_transform_with_canvas().affine_inverse()
	var start_pos: Vector2 = hand_inv * deck_global
	c.position = start_pos
	c.rotation_degrees = 0.0
	c.scale = Vector2.ONE * 0.90
	c.z_index = 1000
	c.set_meta("card_id", id)
	if c.has_method("set_card_id"):
		c.call("set_card_id", id)
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
	print("[DRAW_SLEEK] p=", p.owner_id, " id=", id, " draw_left=", p.draw.size(), " hand_model=", p.hand.size(), " hand_nodes=", count, " dur=", dur)
	var timeout_ms: int = int((dur + 0.25) * 1000.0)
	var t0: int = Time.get_ticks_msec()
	while is_instance_valid(tw) and tw.is_running() and (Time.get_ticks_msec() - t0) < timeout_ms:
		await get_tree().process_frame
	if is_instance_valid(tw) and tw.is_running():
		print("[DRAW_SLEEK] tween timeout, snapping p=", p.owner_id, " id=", id)
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
		var p: PlayerState = _active()
		var id: int = int(deck.pop_back())
		p.hand.append(id)
		var c := card_scene.instantiate() as Control
		if c == null:
			print("[DRAW_BATCH] instantiate failed at i=", i)
			continue
		if c.has_method("set_dealing"):
			c.set_dealing(true)
		if deck_def != null and c.has_method("set_deck_def"):
			c.call("set_deck_def", deck_def)
		hand.add_child(c)
		c.position = start_pos
		c.rotation_degrees = 0.0
		c.scale = Vector2.ONE * 0.90
		c.z_index = 1000 + i
		c.set_meta("card_id", id)
		if c.has_method("set_card_id"):
			c.call("set_card_id", id)
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
	var p: PlayerState = _active()
	var count: int = hand.get_child_count()
	if count <= 0:
		return
	var last := hand.get_child(count - 1) as Control
	if last == null:
		print("[DECK] discard blocked: last not Control")
		return
	if not last.has_meta("card_id"):
		print("[DECK] discard desync: node missing card_id meta, rebuilding hand view")
		_sync_hand_view_from_model()
		return
	var id: int = int(last.get_meta("card_id"))
	var idx: int = p.hand.rfind(id)
	if idx < 0:
		print("[DECK] discard desync: id=", id, " not in model hand, rebuilding hand view")
		_sync_hand_view_from_model()
		return
	p.hand.remove_at(idx)
	p.discard.append(id)
	hand.remove_child(last)
	last.queue_free()
	hand.call("layout_cards_animated", 0.18, null)
	print("[DECK] discard p=", p.owner_id, " id=", id, " discard=", p.discard.size(), " hand_model=", p.hand.size(), " hand_nodes=", hand.get_child_count())

func discard_hand_to_max(owner_idx: int, keep_count: int) -> void:
	_ensure_players()
	var oi: int = clampi(owner_idx, 0, players.size() - 1)
	var p: PlayerState = players[oi]
	var keep: int = maxi(0, keep_count)
	if p.hand.size() <= keep:
		print("[ENDTURN] owner=", oi, " keep=", keep, " nothing to discard hand=", p.hand.size())
		if oi == active_player_idx:
			_sync_hand_view_from_model()
		return
	var to_discard: int = p.hand.size() - keep
	for i in range(to_discard):
		var id: int = int(p.hand.pop_back())
		p.discard.append(id)
	print("[ENDTURN] owner=", oi, " keep=", keep, " discarded=", to_discard, " hand_now=", p.hand.size(), " discard_now=", p.discard.size())
	if oi == active_player_idx:
		_sync_hand_view_from_model()

func _settle_hand_after_deal() -> void:
	await get_tree().create_timer(0.26).timeout
	if hand != null and not _is_dealing:
		hand.call("update_cards")
		print("[DECK_FIX] settle_hand")

func _reshuffle_discard_into_draw(owner_idx: int) -> bool:
	_ensure_players()
	var oi: int = clampi(owner_idx, 0, players.size() - 1)
	var p: PlayerState = players[oi]
	if p.discard.is_empty():
		print("[RESHUFFLE] blocked: discard empty owner=", oi)
		return false
	if not p.draw.is_empty():
		print("[RESHUFFLE] blocked: draw not empty owner=", oi, " draw=", p.draw.size())
		return false
	var moved: int = 0
	for i in range(p.discard.size()):
		p.draw.append(p.discard[i])
		moved += 1
	p.discard.clear()
	if reshuffle_uses_seed:
		var rng := _get_rng()
		for i in range(p.draw.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var tmp: int = p.draw[i]
			p.draw[i] = p.draw[j]
			p.draw[j] = tmp
	else:
		p.draw.shuffle()
	print("[RESHUFFLE] owner=", oi, " moved=", moved, " draw_now=", p.draw.size())
	return true

func _draw_one_model(owner_idx: int) -> int:
	_ensure_players()
	var oi: int = clampi(owner_idx, 0, players.size() - 1)
	var p: PlayerState = players[oi]
	if p.draw.is_empty():
		if reshuffle_discard_when_empty:
			var ok: bool = _reshuffle_discard_into_draw(oi)
			if not ok:
				return -1
		else:
			return -1
	if p.draw.is_empty():
		return -1
	var id: int = int(p.draw.pop_back())
	p.hand.append(id)
	return id

func draw_n(owner_idx: int, n: int) -> Array[int]:
	var out: Array[int] = []
	var want: int = maxi(0, n)
	for i in range(want):
		var id: int = _draw_one_model(owner_idx)
		if id < 0:
			break
		out.append(id)
	print("[DRAW_MODEL] owner=", owner_idx, " want=", want, " got=", out.size(), " draw_left=", _pile(owner_idx, &"draw").size(), " discard=", _pile(owner_idx, &"discard").size(), " hand=", _pile(owner_idx, &"hand").size())
	return out

func discard_hand_to_discard(owner_idx: int) -> void:
	_ensure_players()
	var oi: int = clampi(owner_idx, 0, players.size() - 1)
	var p: PlayerState = players[oi]
	var moved: int = 0
	for i in range(p.hand.size()):
		p.discard.append(p.hand[i])
		moved += 1
	p.hand.clear()
	print("[ENDTURN] owner=", oi, " moved=", moved, " discard_now=", p.discard.size())
	if oi == active_player_idx:
		_sync_hand_view_from_model()

func _card_id_to_text(id: int) -> String:
	if deck_def != null:
		return deck_def.card_id_to_text(id)
	var rank: int = id % 13
	@warning_ignore("integer_division")
	var suit: int = int(id / 13)
	if suit < 0 or suit >= 4 or rank < 0 or rank >= 13:
		return "??"
	return _RANK_STR[rank] + _SUIT_STR[suit]

func _pile(owner_idx: int, zone: StringName) -> Array[int]:
	_ensure_players()
	var oi: int = clampi(owner_idx, 0, players.size() - 1)
	var p: PlayerState = players[oi]
	if zone == &"draw":
		return p.draw
	if zone == &"hand":
		return p.hand
	if zone == &"discard":
		return p.discard
	print("[ZONE] unknown zone=", zone, " defaulting to draw")
	return p.draw

func _move_card(owner_from: int, zone_from: StringName, owner_to: int, zone_to: StringName, id: int = -1) -> int:
	var from_pile: Array[int] = _pile(owner_from, zone_from)
	var to_pile: Array[int] = _pile(owner_to, zone_to)
	if from_pile.is_empty():
		print("[MOVE] blocked empty from owner=", owner_from, " zone=", zone_from)
		return -1
	var moved: int = id
	if moved < 0:
		moved = int(from_pile.pop_back())
	else:
		var idx: int = from_pile.rfind(moved)
		if idx < 0:
			print("[MOVE] blocked missing id=", moved, " from owner=", owner_from, " zone=", zone_from)
			return -1
		from_pile.remove_at(idx)
	to_pile.append(moved)
	print("[MOVE] id=", moved, " ", owner_from, ":", zone_from, " -> ", owner_to, ":", zone_to, " to_size=", to_pile.size())
	return moved

func _sync_hand_view_from_model() -> void:
	if hand == null or card_scene == null:
		return
	var kids: Array[Node] = hand.get_children()
	for i in range(kids.size()):
		var n := kids[i]
		hand.remove_child(n)
		n.queue_free()
	var p: PlayerState = _active()
	for i in range(p.hand.size()):
		var id: int = int(p.hand[i])
		var c := card_scene.instantiate() as Control
		if c == null:
			continue
		if deck_def != null and c.has_method("set_deck_def"):
			c.call("set_deck_def", deck_def)
		c.set_meta("card_id", id)
		if c.has_method("set_card_id"):
			c.call("set_card_id", id)
		hand.add_child(c)
	hand.call("update_cards")
	print("[SYNC] hand_view rebuilt owner=", p.owner_id, " model_hand=", p.hand.size(), " nodes=", hand.get_child_count())

func switch_active_player(new_idx: int) -> void:
	_ensure_players()
	if _is_dealing:
		print("[SWITCH] blocked: dealing")
		return
	active_player_idx = clampi(new_idx, 0, players.size() - 1)
	_sync_hand_view_from_model()
	print("[SWITCH] active_player_idx=", active_player_idx, " draw=", _active().draw.size(), " discard=", _active().discard.size())
	
func _get_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	if reshuffle_uses_seed:
		rng.seed = int(rng_seed)
	return rng

func _debug_top_cards(amount: int) -> String:
	var p: PlayerState = _active()
	var n: int = mini(amount, p.draw.size())
	var out: Array[String] = []
	for i in range(n):
		out.append(_card_id_to_text(p.draw[p.draw.size() - 1 - i]))
	return ",".join(out)
