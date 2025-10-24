# scripts/battle/enemy.gd
extends Area2D

# [新代码] 定义一个信号，当自己被点击时发出
signal enemy_clicked(enemy_instance)

# 这是 Area2D 内置的信号处理器
# 当鼠标点击或悬停在 CollisionShape2D 上时触发
func _on_input_event(viewport, event, shape_idx):
	# 检查是不是鼠标左键按下了
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		print("敌人被点击了!")
		# 发出信号，把自己(self)广播出去
		emit_signal("enemy_clicked", self)
