extends Control

@export var bg_color: Color = Color(0.77, 0.70, 0.55, 1.0)
@export var border_color: Color = Color(0.20, 0.16, 0.10, 1.0)
@export var border_thickness: float = 3.0
@export var hatch_step: float = 10.0
@export var hatch_alpha: float = 0.10

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(r, bg_color, true)
	var bt: float = maxf(1.0, border_thickness)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, bt)), border_color, true)
	draw_rect(Rect2(Vector2.ZERO, Vector2(bt, size.y)), border_color, true)
	draw_rect(Rect2(Vector2(0.0, size.y - bt), Vector2(size.x, bt)), border_color, true)
	draw_rect(Rect2(Vector2(size.x - bt, 0.0), Vector2(bt, size.y)), border_color, true)
	var hatch: Color = Color(border_color.r, border_color.g, border_color.b, hatch_alpha)
	var step: float = maxf(6.0, hatch_step)
	var w: float = size.x
	var h: float = size.y
	var d: float = w + h
	var x: float = -h
	while x <= w:
		draw_line(Vector2(x, 0.0), Vector2(x + h, h), hatch, 1.0, true)
		x += step
	var y: float = -w
	while y <= h:
		draw_line(Vector2(0.0, y), Vector2(w, y + w), hatch, 1.0, true)
		y += step
