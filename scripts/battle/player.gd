# scripts/battle/player.gd
extends Node2D

# 定义一个信号，当属性变化时发出，用于通知UI更新
signal stats_changed(stats)

# 玩家的战斗属性
var health: int = 50:
	set(value):
		health = clamp(value, 0, max_health) # 确保 health 不会<0或>max_health
		emit_stats() # 发出信号

var max_health: int = 50
var block: int = 0: # 真气/护甲
	set(value):
		block = max(value, 0) # 确保 block 不会<0
		emit_stats()

func _ready():
	# 战斗开始时，确保UI是同步的
	emit_stats()

# 发出信号的辅助函数
func emit_stats():
	# 把所有属性打包成一个字典(Dictionary)发送出去
	var stats = {
		"health": health,
		"max_health": max_health,
		"block": block
	}
	emit_signal("stats_changed", stats)

# --- 供 BattleManager 调用的"公共API" ---

# 受到伤害
func take_damage(amount: int):
	print("玩家受到 %d 伤害" % amount)
	var damage_remaining = amount
	
	if block > 0:
		var block_damage = min(block, damage_remaining) # 计算护甲能挡多少
		block -= block_damage
		damage_remaining -= block_damage
		print("护甲抵挡了 %d, 剩余 %d" % [block_damage, damage_remaining])
	
	if damage_remaining > 0:
		health -= damage_remaining
		print("生命值降低到 %d" % health)
	
	# (以后在这里播放"受伤"动画)

# 增加护甲
func add_block(amount: int):
	print("玩家获得 %d 真气" % amount)
	block += amount

# 回合开始时调用
func on_turn_start():
	block = 0
	# 圣遗物/Buff结算... (暂时留空)
	pass

# 回合结束时调用
func on_turn_end():
	pass
