# scripts/battle/projectile.gd
extends Node2D

# 这两个变量将由 BattleManager 传入
var target: Node2D = null
var speed: float = 1000.0 # 像素/秒

func _process(delta: float):
	# 如果没有目标，就什么也别做
	if not is_instance_valid(target):
		queue_free() # 目标可能已经死了，销毁自己
		return
	
	# 1. 获取目标位置
	var target_pos = target.global_position
	
	# 2. 检查距离
	var distance_to_target = global_position.distance_to(target_pos)
	
	if distance_to_target < 20: # 阈值 (小于20像素就算“击中”)
		# 3. 击中目标
		print("投射物击中!")
		# (以后在这里播放“击中”特效)
		queue_free() # 销毁自己
	else:
		# 4. 飞向目标
		global_position = global_position.move_toward(target_pos, speed * delta)
		# 5. (可选) 旋转自己，朝向目标
		look_at(target_pos)
