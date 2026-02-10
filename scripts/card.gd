extends Control

@export var card_size := Vector2(210, 294)
@onready var visual: Control = $Visual
@onready var face: Sprite2D = $Visual/Face
@onready var shadow: Sprite2D = $Visual/Face/Shadow

var shadow_offset: Vector2 = Vector2(-12, 12)
var mouse_in: bool = false
var is_dragging: bool = false
var base_face_scale: Vector2 = Vector2.ONE
var current_goal_scale: float = -1.0
var scale_tween: Tween = null
var idle_scale_mult: float = 1.0
var hover_scale_mult: float = 1.22
var drag_scale_mult: float = 1.30
var last_global_pos: Vector2 = Vector2.ZERO
var max_card_rotation: float = 12.0
var tilt_max_deg: float = 14.0
var tilt_current: Vector2 = Vector2.ZERO
var tilt_lerp_speed: float = 14.0
var face_mat: ShaderMaterial = null
var tilt_last_pos: Vector2 = Vector2.ZERO
var hover_tilt_max_deg: float = 8.0
var drag_tilt_max_deg: float = 18.0
var drag_tilt_deg_per_px: float = 0.35
var drag_grab_offset: Vector2 = Vector2.ZERO
var shadow_mat: ShaderMaterial = null
var shadow_tilt_mult: float = 0.85

func _ready() -> void:
	custom_minimum_size = card_size
	size = card_size
	pivot_offset = Vector2(size.x * 0.5, size.y)
	visual.pivot_offset = pivot_offset
	_fit_face()
	if face.material != null:
		face.material = face.material.duplicate()
		face_mat = face.material as ShaderMaterial
		print("[CARD_3D] mat_ok=", face_mat != null)
		print("[CARD_3D] has_face_material=", face.material != null)
	if face_mat != null and face.texture != null:
		face_mat.set_shader_parameter("rect_size", face.texture.get_size())
		face_mat.set_shader_parameter("inset", 0.12)
		face_mat.set_shader_parameter("fov", 90.0)
		face_mat.set_shader_parameter("cull_back", true)
		print("[CARD_3D] rect_size=", face.texture.get_size(), " inset=0.12")
	if shadow != null:
		if face_mat != null:
			shadow.material = face_mat.duplicate()
		elif shadow.material != null:
			shadow.material = shadow.material.duplicate()
		shadow_mat = shadow.material as ShaderMaterial
		if shadow_mat != null:
			shadow_mat.set_shader_parameter("cull_back", false)
		print("[CARD_SHADOW] mat_ok=", shadow_mat != null)
	last_global_pos = global_position
	base_face_scale = face.scale
	shadow.position = shadow_offset
	tilt_last_pos = global_position
	print("[CARD] shadow offset=", shadow.position)
	print("[CARD] ready size=", size, " pivot=", pivot_offset)

func _fit_face() -> void:
	if face.texture == null:
		print("[CARD] no texture on Face")
		return
	var tex_size := face.texture.get_size()
	var scale_factor: float = minf(
	card_size.x / float(tex_size.x),
	card_size.y / float(tex_size.y)
	)
	face.scale = Vector2.ONE * scale_factor
	face.position = card_size * 0.5
	print("[CARD] tex=", tex_size, " scale=", face.scale)

func _update_shadow() -> void:
	shadow.position = shadow_offset.rotated(-(rotation + visual.rotation))

func _update_tilt(delta: float) -> void:
	if face_mat == null:
		return
	var target := Vector2.ZERO
	if MouseBrain.node_being_dragged != null and MouseBrain.node_being_dragged != self:
		target = Vector2.ZERO
	elif is_dragging:
		var dpos: Vector2 = global_position - tilt_last_pos
		var pitch_deg: float = clampf(-dpos.y * drag_tilt_deg_per_px, -drag_tilt_max_deg, drag_tilt_max_deg)
		var yaw_deg: float = clampf(dpos.x * drag_tilt_deg_per_px, -drag_tilt_max_deg, drag_tilt_max_deg)
		target = Vector2(pitch_deg, yaw_deg)
	elif mouse_in:
		var mouse_vp: Vector2 = get_viewport().get_mouse_position()
		var centre: Vector2 = global_position + size * 0.5
		var rel: Vector2 = mouse_vp - centre
		var half: Vector2 = size * 0.5
		var norm := Vector2(
			clampf(rel.x / half.x, -1.0, 1.0),
			clampf(rel.y / half.y, -1.0, 1.0)
		)
		target = Vector2(
			-norm.y * hover_tilt_max_deg,
			norm.x * hover_tilt_max_deg
		)
	tilt_last_pos = global_position
	tilt_current = tilt_current.lerp(target, tilt_lerp_speed * delta)
	face_mat.set_shader_parameter("x_rot", tilt_current.x)
	face_mat.set_shader_parameter("y_rot", tilt_current.y)
	if shadow_mat != null:
		shadow_mat.set_shader_parameter("x_rot", tilt_current.x * shadow_tilt_mult)
		shadow_mat.set_shader_parameter("y_rot", tilt_current.y * shadow_tilt_mult)



func _on_mouse_entered() -> void:
	mouse_in = true
	print("[CARD] mouse_in=true")

func _on_mouse_exited() -> void:
	mouse_in = false
	print("[CARD] mouse_in=false")

func _physics_process(delta: float) -> void:
	drag_logic(delta)
	_update_tilt(delta)
	_update_shadow()
	polish_logic()

func drag_logic(delta: float) -> void:
	if not mouse_in and not is_dragging:
		return
	if MouseBrain.node_being_dragged != null and MouseBrain.node_being_dragged != self:
		return
	if Input.is_action_pressed("Lclick"):
		if not is_dragging:
			print("[CARD_DRAG] start")
			drag_grab_offset = global_position - get_global_mouse_position()
		is_dragging = true
		MouseBrain.node_being_dragged = self
		var p := get_parent()
		if p != null and p.has_method("update_cards"):
			p.call_deferred("update_cards")
		var target: Vector2 = get_global_mouse_position() + drag_grab_offset
		global_position = global_position.lerp(target, 22.0 * delta)
		z_index = 100
		_set_rotation(delta)
	else:
		if is_dragging:
			print("[CARD_DRAG] stop")
		is_dragging = false
		if MouseBrain.node_being_dragged == self:
			MouseBrain.node_being_dragged = null
		z_index = 0
		visual.rotation_degrees = lerpf(visual.rotation_degrees, 0.0, 12.0 * delta)
		last_global_pos = global_position

func polish_logic() -> void:
	if is_dragging:
		z_index = 100
		change_scale(drag_scale_mult)
		return
	z_index = 0
	if mouse_in:
		if MouseBrain.node_being_dragged != null and MouseBrain.node_being_dragged != self:
			change_scale(idle_scale_mult)
			return
		change_scale(hover_scale_mult)
		return
	change_scale(idle_scale_mult)
	# Idle state: ensure visuals settle back cleanly
	visual.rotation_degrees = lerpf(visual.rotation_degrees, 0.0, 12.0 * get_physics_process_delta_time())

func change_scale(desired_mult: float) -> void:
	if is_equal_approx(desired_mult, current_goal_scale):
		return
	current_goal_scale = desired_mult
	if scale_tween != null and scale_tween.is_running():
		scale_tween.kill()
	scale_tween = create_tween()
	scale_tween.set_ease(Tween.EASE_OUT)
	scale_tween.set_trans(Tween.TRANS_ELASTIC)
	var target_scale: Vector2 = base_face_scale * desired_mult
	scale_tween.tween_property(face, "scale", target_scale, 0.14)

func _set_rotation(delta: float) -> void:
	var x_delta: float = global_position.x - last_global_pos.x
	var desired: float = clampf(x_delta * 0.85, -max_card_rotation, max_card_rotation)
	visual.rotation_degrees = lerpf(visual.rotation_degrees, desired, 12.0 * delta)
	last_global_pos = global_position
