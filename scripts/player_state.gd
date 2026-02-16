class_name PlayerState
extends RefCounted

var owner_id: int = 0
var draw: Array[int] = []
var hand: Array[int] = []
var discard: Array[int] = []

func _init(id: int = 0) -> void:
	owner_id = id
