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
var is_dealing: bool = false
var drag_rot_target: float = 0.0
var vel_last_global_pos: Vector2 = Vector2(INF, INF)
var vel_rot_current: float = 0.0
var vel_tilt_max_deg: float = 9.0
var vel_tilt_deg_per_speed: float = 0.008
var vel_tilt_lerp_speed: float = 18.0

@export var vel_debug: bool = false

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

func _update_velocity_tilt(delta: float) -> void:
	if is_inf(vel_last_global_pos.x):
		vel_last_global_pos = global_position
		vel_rot_current = 0.0
		return
	var safe_dt: float = maxf(delta, 0.00001)
	var vel: Vector2 = (global_position - vel_last_global_pos) / safe_dt
	vel_last_global_pos = global_position
	var target: float = clampf(vel.x * vel_tilt_deg_per_speed, -vel_tilt_max_deg, vel_tilt_max_deg)
	target += clampf(-vel.y * (vel_tilt_deg_per_speed * 0.35), -(vel_tilt_max_deg * 0.35), vel_tilt_max_deg * 0.35)
	vel_rot_current = lerpf(vel_rot_current, target, vel_tilt_lerp_speed * delta)
	if vel_debug and absf(target) > 0.9:
		print("[VEL_TILT] v=", vel, " target=", target, " cur=", vel_rot_current)

func _apply_visual_rotation(delta: float) -> void:
	if visual == null:
		return
	var target: float = drag_rot_target + vel_rot_current
	visual.rotation_degrees = lerpf(visual.rotation_degrees, target, 14.0 * delta)

func _on_mouse_entered() -> void:
	mouse_in = true
	print("[CARD] mouse_in=true")

func _on_mouse_exited() -> void:
	mouse_in = false
	print("[CARD] mouse_in=false")

func _physics_process(delta: float) -> void:
	drag_logic(delta)
	_update_velocity_tilt(delta)
	_apply_visual_rotation(delta)
	_update_tilt(delta)
	_update_shadow()
	polish_logic()

func drag_logic(delta: float) -> void:
	if is_dealing:
		return
	if not mouse_in and not is_dragging:
		return
	if MouseBrain.node_being_dragged != null and MouseBrain.node_being_dragged != self:
		return
	if Input.is_action_pressed("Lclick"):
		if not is_dragging:
			print("[CARD_DRAG] start")
			drag_grab_offset = global_position - get_global_mouse_position()
			rotation_degrees = 0.0
			visual.rotation_degrees = 0.0
			last_global_pos = global_position
			is_dragging = true
			MouseBrain.node_being_dragged = self
			var p := get_parent()
			if p != null and p.has_method("layout_cards_animated"):
				p.call("layout_cards_animated", 0.12, self)
		if not is_dragging:
			return
		rotation_degrees = 0.0
		visual.rotation_degrees = 0.0
		var target: Vector2 = get_global_mouse_position() + drag_grab_offset
		global_position = global_position.lerp(target, 22.0 * delta)
		z_index = 100
	else:
		if is_dragging:
			print("[CARD_DRAG] stop")
		if not is_dragging:
			return
		is_dragging = false
		if MouseBrain.node_being_dragged == self:
			MouseBrain.node_being_dragged = null
		z_index = 0
		visual.rotation_degrees = 0.0
		last_global_pos = global_position
		var p := get_parent()
		if p != null and p.has_method("layout_cards_animated"):
			p.call("layout_cards_animated", 0.18, null)

func polish_logic() -> void:
	if is_dealing:
		z_index = 150
		change_scale(idle_scale_mult)
		return
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

func _set_rotation(_delta: float) -> void:
	var x_delta: float = global_position.x - last_global_pos.x
	drag_rot_target = clampf(x_delta * 0.85, -max_card_rotation, max_card_rotation)
	last_global_pos = global_position

func set_dealing(value: bool) -> void:
	is_dealing = value
