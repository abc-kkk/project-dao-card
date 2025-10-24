# scripts/battle/enemy.gd
extends Area2D

# [新代码] 定义一个信号，当自己被点击时发出
signal enemy_clicked(enemy_instance)
signal stats_changed(stats)
signal enemy_died
# [新代码] 定义一个信号，告诉 BattleManager 它想攻击
signal wants_to_attack(damage)

# 敌人的战斗属性
var health: int = 30:
	set(value):
		health = clamp(value, 0, max_health)
		emit_stats()
		if health == 0:
			emit_signal("enemy_died")

var max_health: int = 30
var block: int = 0:
	set(value):
		block = max(value, 0)
		emit_stats()

func _ready():
	emit_stats()
	
# 这是 Area2D 内置的信号处理器
# 当鼠标点击或悬停在 CollisionShape2D 上时触发
func _on_input_event(viewport, event, shape_idx):
	# 检查是不是鼠标左键按下了
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		print("敌人被点击了!")
		# 发出信号，把自己(self)广播出去
		emit_signal("enemy_clicked", self)

func emit_stats():
	var stats = {
		"health": health,
		"max_health": max_health,
		"block": block
	}
	emit_signal("stats_changed", stats)

# --- 供 BattleManager 调用的“公共API” ---

func take_damage(amount: int):
	print("敌人受到 %d 伤害" % amount)
	var damage_remaining = amount
	
	if block > 0:
		var block_damage = min(block, damage_remaining)
		block -= block_damage
		damage_remaining -= block_damage
	
	if damage_remaining > 0:
		health -= damage_remaining
	
	if health == 0:
		print("敌人已死亡")
		# (以后在这里播放“死亡”动画)
		queue_free() # 暂时先直接消失

func add_block(amount: int):
	block += amount

func do_action():
	# 敌人的AI (暂时留空)
	# 这是一个非常简单的 "AI": 总是攻击 5 点伤害
	var attack_damage = 5 
	print("敌人行动！ 准备攻击 %d 点伤害" % attack_damage)

	# [新代码] 发出信号，让 BattleManager 去处理
	emit_signal("wants_to_attack", attack_damage)
	
