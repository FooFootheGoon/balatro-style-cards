extends Control

@export var card_scene: PackedScene
@export var y_curve: Curve
@export var rot_curve: Curve
@export var max_rot_deg: float = 10.0
@export var x_sep_px: float = 40.0
@export var y_min_px: float = -260.0
@export var y_max_px: float = 50.0
@export var card_size_px: Vector2 = Vector2(210, 294)
@export var wave_enabled: bool = true
@export var wave_amp_px: float = 4.0
@export var wave_freq_hz: float = 0.6
@export var wave_phase_step: float = 0.5
@export var wave_pause_after_layout_s: float = 0.35

var _wave_t: float = 0.0
var _wave_paused_until_ms: int = 0
var _drag_last_index: int = -1
var _drag_preview_tw: Tween	

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
	var t01: float = 0.5
	if count > 1:
		t01 = float(index) / float(count - 1)
	var y_p: float = 0.0
	if y_curve != null:
		y_p = y_curve.sample(t01)
	var x: float = offset_x + (float(index) * (card_w + final_sep))
	var y: float = y_min_px - (y_max_px * y_p)
	var t_signed: float = 0.0
	if count > 1:
		t_signed = (t01 * 2.0) - 1.0
	var s: float = 0.0
	if t_signed < 0.0:
		s = -1.0
	elif t_signed > 0.0:
		s = 1.0
	var t_abs: float = t_signed
	if t_abs < 0.0:
		t_abs = -t_abs
	var r_mag: float = 0.0
	if rot_curve != null:
		r_mag = rot_curve.sample(t_abs)
	var rot_deg: float = s * max_rot_deg * r_mag
	return {"pos": Vector2(x, y), "rot_deg": rot_deg, "sep": final_sep}

func layout_cards_animated(duration: float = 0.22, skip: Control = null) -> Tween:
	if has_method("pause_wave"):
		call("pause_wave", duration + 0.06)
	var cards: Array[Node] = get_children()
	var count: int = cards.size()
	if count == 0:
		return null
	var dragged := MouseBrain.node_being_dragged
	var has_targets: bool = false
	for i in range(count):
		var c := cards[i] as Control
		if c == null:
			continue
		if c == dragged:
			continue
		if skip != null and c == skip:
			continue
		has_targets = true
		break
	if not has_targets:
		print("[HAND_FIX] layout_cards_animated: no targets, count=", count)
		return null
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
	print("[HAND_FIX] tween_layout targets_ok count=", count, " dur=", duration)
	return tw

func update_cards() -> void:
	pause_wave(wave_pause_after_layout_s)
	var cards: Array[Node] = get_children()
	var count: int = cards.size()
	if count == 0:
		return
	var dragged := MouseBrain.node_being_dragged
	for i in range(count):
		var c := cards[i] as Control
		if c == null:
			continue
		if c == dragged:
			continue
		if c.has_method("set_dealing") and bool(c.get("is_dealing")):
			continue
		var layout := get_layout_for_index(i, count)
		c.position = layout["pos"]
		c.rotation_degrees = layout["rot_deg"]
		c.set_meta("_wave_off_y", 0.0)

func pause_wave(seconds: float) -> void:
	var until_ms: int = Time.get_ticks_msec() + int(maxf(0.0, seconds) * 1000.0)
	_wave_paused_until_ms = maxi(_wave_paused_until_ms, until_ms)

func _process(delta: float) -> void:
	if not wave_enabled:
		return
	var cards: Array[Node] = get_children()
	var count: int = cards.size()
	if count <= 0:
		return
	var dragged := MouseBrain.node_being_dragged as Control
	if dragged != null and dragged.get_parent() == self:
		var x_center: float = dragged.position.x + (dragged.size.x * 0.5)
		var target_index: int = 0
		for i in range(count):
			var layout_i: Dictionary = get_layout_for_index(i, count)
			var slot_center: float = layout_i["pos"].x + (dragged.size.x * 0.5)
			if x_center > slot_center:
				target_index = i + 1
		target_index = clampi(target_index, 0, count - 1)
		if target_index != _drag_last_index:
			_drag_last_index = target_index
			if dragged.get_index() != target_index:
				move_child(dragged, target_index)
			if _drag_preview_tw != null and is_instance_valid(_drag_preview_tw) and _drag_preview_tw.is_running():
				_drag_preview_tw.kill()
			pause_wave(0.20)
			_drag_preview_tw = layout_cards_animated(0.12, dragged)
		_wave_t += delta
		for i in range(count):
			var c := cards[i] as Control
			if c == null:
				continue
			if c == dragged:
				continue
			if c.has_method("set_dealing") and bool(c.get("is_dealing")):
				continue
			var prev_off: float = 0.0
			if c.has_meta("_wave_off_y"):
				prev_off = float(c.get_meta("_wave_off_y"))
			var base_y: float = c.position.y - prev_off
			var phase: float = (_wave_t * TAU * wave_freq_hz) + (float(i) * wave_phase_step)
			var new_off: float = sin(phase) * wave_amp_px
			c.position = Vector2(c.position.x, base_y + new_off)
			c.set_meta("_wave_off_y", new_off)
		return
	_drag_last_index = -1
	if Time.get_ticks_msec() < _wave_paused_until_ms:
		return
	var pause_now: bool = false
	for i in range(count):
		var c := cards[i] as Control
		if c == null:
			continue
		if bool(c.get("mouse_in")):
			pause_now = true
			break
		if c.has_method("set_dealing") and bool(c.get("is_dealing")):
			pause_now = true
			break
	if pause_now:
		for i in range(count):
			var c := cards[i] as Control
			if c == null:
				continue
			if c.has_method("set_dealing") and bool(c.get("is_dealing")):
				continue
			var layout: Dictionary = get_layout_for_index(i, count)
			c.position = layout["pos"]
			c.rotation_degrees = layout["rot_deg"]
			c.set_meta("_wave_off_y", 0.0)
		return
	_wave_t += delta
	for i in range(count):
		var c := cards[i] as Control
		if c == null:
			continue
		var layout: Dictionary = get_layout_for_index(i, count)
		var base: Vector2 = layout["pos"]
		var phase: float = (_wave_t * TAU * wave_freq_hz) + (float(i) * wave_phase_step)
		c.position = Vector2(base.x, base.y + (sin(phase) * wave_amp_px))
		c.rotation_degrees = layout["rot_deg"]
		c.set_meta("_wave_off_y", 0.0)
