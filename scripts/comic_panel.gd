class_name ComicPanel
extends Control
## 만화 한 칸. painter(canvas, 크기, 시간)가 매 프레임 그림을 다시 그려 살짝 움직인다.

var painter: Callable
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	if painter.is_valid():
		painter.call(self, size, _t)
