extends Control

@export var card_back_scene: PackedScene
@export var card_size: Vector2 = Vector2(240, 336)
@export var stack_offset_px: Vector2 = Vector2(-0.35, -0.35)
@export var max_visual_count: int = 9999

func set_count(new_count: int) -> void:
	var want: int = clampi(new_count, 0, max_visual_count)
	var have: int = get_child_count()
	while have < want:
		if card_back_scene == null:
			print("[STACK] missing card_back_scene")
			return
		var c := card_back_scene.instantiate() as Control
		if c == null:
			print("[STACK] instantiate failed")
			return
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.custom_minimum_size = card_size
		c.size = card_size
		add_child(c)
		have += 1
	while have > want:
		var n: Node = get_child(have - 1)
		remove_child(n)
		n.queue_free()
		have -= 1
	for i in range(have):
		var cc := get_child(i) as Control
		if cc != null:
			cc.custom_minimum_size = card_size
			cc.size = card_size
			cc.position = Vector2(float(i) * stack_offset_px.x, float(i) * stack_offset_px.y)
			cc.z_index = i

func get_deal_origin_global() -> Vector2:
	var n: int = get_child_count()
	if n > 0:
		var top := get_child(n - 1) as Control
		if top != null:
			return top.get_global_transform_with_canvas().origin
	return get_global_transform_with_canvas().origin
