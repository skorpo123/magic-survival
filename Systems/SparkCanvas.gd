extends Node2D

var _owner = null

func _draw() -> void:
	if not _owner or not is_instance_valid(_owner):
		return
	var data: PackedFloat32Array = _owner._spark_data
	var alive: PackedInt32Array = _owner._spark_alive
	var colors: PackedFloat32Array = _owner._spark_colors
	for i in range(alive.size()):
		if alive[i] == 0:
			continue
		var off: int = i * 4
		var px: float = data[off]
		var py: float = data[off + 1]
		var coff: int = i * 4
		var r: float = colors[coff]
		var g: float = colors[coff + 1]
		var b: float = colors[coff + 2]
		var a: float = colors[coff + 3]
		if a <= 0.0:
			continue
		draw_circle(Vector2(px, py), 3.0, Color(r, g, b, a))
