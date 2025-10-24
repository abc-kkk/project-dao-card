# scripts/battle/battle.gd
extends Node2D

# -------- 预加载资源 --------
# 预加载“卡牌UI”场景。我们必须先加载它，才能在代码里“实例化”它。
const CardUI_Scene = preload("res://scenes/ui/card_ui.tscn")

# 预加载我们的卡牌“数据”。
const BasicStrike_Data = preload("res://data/cards/basic_strike.tres")
const BasicDefend_Data = preload("res://data/cards/basic_defend.tres")
# 投射物
const Projectile_Scene = preload("res://scenes/battle/projectile.tscn")

# -------- 节点引用 --------
# 引用UI，以便更新它们
@onready var hand_container: HBoxContainer = $UI_Layer/BattleUI/HandContainer
@onready var draw_pile_label: Label = $UI_Layer/BattleUI/PileContainer/DrawPileLabel
@onready var discard_pile_label: Label = $UI_Layer/BattleUI/PileContainer/DiscardPileLabel
@onready var energy_label: Label = $UI_Layer/BattleUI/EnergyLabel
@onready var aiming_arrow: Line2D = $AimingArrow
@onready var player: Node2D = $Player
@onready var enemy: Area2D = $Enemy 
# 按钮引用
@onready var end_turn_button: Button = $UI_Layer/BattleUI/EndTurnButton

# 玩家状态UI引用
@onready var player_health_label: Label = $UI_Layer/BattleUI/PlayerStatsUI/PlayerHealthLabel
@onready var player_block_label: Label = $UI_Layer/BattleUI/PlayerStatsUI/PlayerBlockLabel

# 敌人状态UI引用
@onready var enemy_health_label: Label = $UI_Layer/BattleUI/EnemyStatsUI/EnemyHealthLabel
@onready var enemy_block_label: Label = $UI_Layer/BattleUI/EnemyStatsUI/EnemyBlockLabel

# -------- 战斗状态变量 --------
# 我们用数组(Array)来管理卡牌“数据”(CardData)，而不是卡牌“场景”(CardUI)
var deck: Array[CardData] = []         # 玩家的总牌库
var draw_pile: Array[CardData] = []    # 抽牌堆
var hand: Array[CardData] = []         # 手牌 (只存数据)
var discard_pile: Array[CardData] = [] # 弃牌堆

var energy: int = 3
var energy_max: int = 3

# [新代码] 状态管理
var is_waiting_for_target: bool = false # 是否在等待玩家选择目标
var card_pending_target: CardData = null    # 哪张卡在等待？ (数据)
var card_ui_pending_target: Control = null  # 哪张卡在等待？ (UI)


# -------- Godot 核心函数 --------
# 当场景启动时，自动调用
func _ready():
	start_battle()
	# [新代码] 连接所有敌人的点击信号
	# get_tree().call_group("group_name", "function_name", ...args)
	# 这会告诉 "enemies" 分组里的所有节点，
	# 当它们发出 "enemy_clicked" 信号时，
	# 调用我们(self)的 "on_enemy_clicked" 函数
	get_tree().call_group("enemies", "connect", "enemy_clicked", on_enemy_clicked)
	
	# [新代码] 连接状态UI信号
	player.stats_changed.connect(update_player_stats_ui)
	enemy.stats_changed.connect(update_enemy_stats_ui)

	# [新代码] 连接回合结束按钮
	end_turn_button.pressed.connect(on_end_turn_pressed)
	# 它告诉 battle.gd 去“收听”敌人的“wants_to_attack”信号
	enemy.wants_to_attack.connect(on_enemy_attacks)
	
# [修正] 替换整个 _process 函数
func _process(delta: float):
	if is_waiting_for_target:
		aiming_arrow.visible = true
		aiming_arrow.global_position = Vector2.ZERO # 让 Line2D 的坐标和世界坐标一致
		
		# 1. 获取起点和终点
		var start_pos = card_ui_pending_target.get_global_rect().get_center()
		var end_pos = get_global_mouse_position()
		
		aiming_arrow.clear_points() # 清空旧的点
		
		# 2. 计算两个控制点 (Cubic Bezier)
		
		# 基础弧度高度 (可以调整这个值)
		var arc_height = 100.0
		
		# 计算起点和终点的Y轴差距
		var height_diff = start_pos.y - end_pos.y
		
		# 根据Y轴差距，动态调整弧度，让它更“带感”
		# clamp 函数确保缩放比例在 0.5 到 3.0 之间
		var dynamic_arc_scale = clamp(height_diff / 300.0, 0.5, 3.0)
		
		# 第一个控制点 (control_1): 
		# 放在 "起点" 正上方，但X轴向 "终点" 靠拢一点 (比如 25% 的距离)
		var control_1 = start_pos.lerp(end_pos, 0.25) # lerp 是线性插值
		control_1.y -= arc_height * dynamic_arc_scale
		
		# 第二个控制点 (control_2):
		# 放在 "终点" 正上方，但X轴向 "起点" 靠拢一点 (比如 75% 的距离)
		var control_2 = start_pos.lerp(end_pos, 0.75)
		control_2.y -= arc_height * dynamic_arc_scale

		# 3. 用贝塞尔曲线生成所有点
		var num_segments = 20 # 线的平滑度
		for i in range(num_segments + 1):
			var t = float(i) / num_segments
			
			# [修正] 调用正确的4参数函数
			var point_on_curve = start_pos.bezier_interpolate(control_1, control_2, end_pos, t)
			
			aiming_arrow.add_point(point_on_curve)
		
	else:
		# 我们不在瞄准，确保箭头是隐藏的
		if aiming_arrow.visible:
			aiming_arrow.visible = false
			aiming_arrow.clear_points()
# -------- 核心战斗函数 --------

# 1. 开始战斗
func start_battle():
	# a. 构建玩家的初始牌库
	deck = [
		BasicStrike_Data, BasicStrike_Data, BasicStrike_Data, BasicStrike_Data, BasicStrike_Data,
		BasicDefend_Data, BasicDefend_Data, BasicDefend_Data, BasicDefend_Data, BasicDefend_Data
	] # 5张拳法, 5张心法
	
	# b. 复制到抽牌堆并洗牌
	draw_pile = deck.duplicate() # 复制牌库
	draw_pile.shuffle()          # 洗牌！
	
	# c. 重置能量
	energy = energy_max
	
	# d. 更新UI显示
	update_ui()
	
	# e. 抽5张初始手牌
	await draw_cards(5)



# [重构]
# 2. 抽卡
func draw_cards(amount: int):
	
	var draw_start_pos = draw_pile_label.get_global_rect().get_center()
	var animation_duration = 0.3 # 抽牌动画时长
	var delay_between_cards = 0.1 # 每张卡抽出的间隔
	var current_delay = 0.0

	for i in range(amount):
		# a. 检查抽牌堆是否为空？
		if draw_pile.is_empty():
			shuffle_discard_into_draw_pile()
			if draw_pile.is_empty():
				print("牌库已抽干！")
				break
		
		# d. 从抽牌堆顶部拿走一张卡牌数据
		var card_data_to_draw: CardData = draw_pile.pop_front()
		
		# e. 将这张卡牌“数据”添加到手牌“数组”中
		hand.append(card_data_to_draw)
		
		# f. “实例化”卡牌UI场景
		var card_ui_instance = CardUI_Scene.instantiate()
		
		# g. 【关键】把卡牌“数据”喂给卡牌“UI”
		card_ui_instance.data = card_data_to_draw
		card_ui_instance.card_clicked.connect(on_card_clicked)
		# --- [新动画逻辑] ---
		
		# 1. 先让卡牌“隐形”
		card_ui_instance.modulate.a = 0.0
		# 2. 设置一个初始旋转 (像 StS 一样)
		card_ui_instance.rotation_degrees = -90
		
		# 3. 【关键】把实例化的卡牌UI，作为子节点添加到 HandContainer 中
		hand_container.add_child(card_ui_instance)
		
		# 4. 【关键】等待一帧，让 HBoxContainer 重新计算所有卡牌的位置
		await get_tree().create_timer(0.01).timeout # 等待一个极短的时间
		
		# 5. 获取 HBoxContainer 分配给它的“最终位置”
		var final_pos = card_ui_instance.global_position
		
		# 6. 【戏法】把卡牌“瞬移”到抽牌堆的位置
		card_ui_instance.global_position = draw_start_pos
		
		# 7. 让卡牌“现形”
		card_ui_instance.modulate.a = 1.0
		
		# 8. 创建 Tween 动画
		var tween = create_tween()
		#tween.set_delay(current_delay) # 延迟，实现一张张抽
		current_delay += delay_between_cards
		
		tween.set_parallel(true) # 位置和旋转同时进行
		
		# 9. 动画: 移动到最终位置
		tween.tween_property(card_ui_instance, "global_position", final_pos, animation_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		# 10. 动画: 旋转回 0 度
		tween.tween_property(card_ui_instance, "rotation_degrees", 0, animation_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
	# 抽完卡后，更新一下UI
	update_ui()
	
	# [新] 等待最后一张卡牌的动画播放完毕
	var total_wait_time = current_delay + animation_duration
	await get_tree().create_timer(total_wait_time).timeout

# 3. 洗牌
func shuffle_discard_into_draw_pile():
	print("洗牌中...")
	# a. 将弃牌堆所有卡牌“数据”移动到抽牌堆
	draw_pile = discard_pile.duplicate()
	# b. 清空弃牌堆
	discard_pile.clear()
	# c. 洗牌
	draw_pile.shuffle()


# 4. 更新UI
func update_ui():
	# 更新标签上的数字
	draw_pile_label.text = "抽牌堆: %d" % draw_pile.size()
	discard_pile_label.text = "弃牌堆: %d" % discard_pile.size()
	energy_label.text = "灵力: %d/%d" % [energy, energy_max]

# [新函数]
# 当 player 发出 "stats_changed" 信号时调用
func update_player_stats_ui(stats: Dictionary):
	player_health_label.text = "HP: %d/%d" % [stats.health, stats.max_health]
	player_block_label.text = "真气: %d" % stats.block

# [新函数]
# 当 enemy 发出 "stats_changed" 信号时调用
func update_enemy_stats_ui(stats: Dictionary):
	enemy_health_label.text = "HP: %d/%d" % [stats.health, stats.max_health]
	enemy_block_label.text = "护甲: %d" % stats.block

# [重构] 修改 on_card_clicked 函数
func on_card_clicked(card_ui: Control, card_data: CardData):

	# 0. 如果已经在瞄准，不允许点别的卡
	if is_waiting_for_target:
		print("请先选择一个目标 (或右键取消)")
		return

	# 1. 检查能量
	if energy >= card_data.cost:
		# 2. 检查是否需要目标
		if card_data.target_type == CardData.TargetType.NONE:
			# 不需要目标 (如“心法”)，立即打出
			await play_card(card_ui, card_data, null) # null 表示没有目标

		elif card_data.target_type == CardData.TargetType.ENEMY:
			# 需要目标 (如“拳法”)，进入“等待目标”状态
			is_waiting_for_target = true
			card_pending_target = card_data
			card_ui_pending_target = card_ui
			print("进入瞄准状态，请选择一个敌人...")
			# (以后在这里显示瞄准箭头)

		# (以后在这里处理 ALL_ENEMIES, SELF 等)

	else:
		# 3. 能量不足
		print("能量不足！")
		
# [新函数] 真正执行出牌的逻辑
func play_card(card_ui: Control, card_data: CardData, target: Node2D):
	print("打出卡牌: ", card_data.title)

	# a. 扣除能量
	energy -= card_data.cost

	# b. 执行效果
	apply_card_effect(card_data, target)

	# c. 移动卡牌 (数据 和 UI)
	hand.erase(card_data)
	discard_pile.append(card_data)
	# 销毁卡牌
	await card_ui.play_destroy_animation()

	# d. 清理状态 (无论如何都清理)
	cancel_aiming()

	# e. 更新UI
	update_ui()

# [修正] 确保 cancel_aiming 也清空点
func cancel_aiming():
	print("取消瞄准")
	is_waiting_for_target = false
	card_pending_target = null
	card_ui_pending_target = null
	
	# 立即隐藏箭头并清空点
	aiming_arrow.visible = false
	aiming_arrow.clear_points()
	
# [重构]
func apply_card_effect(card_data: CardData, target: Node2D):
	# (target 在这里就是 enemy 实例)

	if card_data.damage > 0:
		if target and is_instance_valid(target): # 确保目标存在
			# 1. [逻辑] 立即造成伤害
			target.take_damage(card_data.damage)

			# 2. [表现] 生成一个“飞行特效”
			var projectile = Projectile_Scene.instantiate()
			projectile.target = target # 告诉投射物要飞向谁

			# 把投射物添加到场景中 (放在 Battle 节点下)
			# 并设置它的起始位置为玩家的位置
			projectile.global_position = player.global_position
			add_child(projectile)

		else:
			print("错误：攻击卡没有目标！") 

	if card_data.block > 0:
		player.add_block(card_data.block)
		
		
# 当任何一个在 "enemies" 分组的节点发出 "enemy_clicked" 信号时调用
func on_enemy_clicked(enemy_instance: Node2D):
	print("BattleManager 监听到敌人被点击: ", enemy_instance.name)

	# 检查我们是否在等待目标
	if is_waiting_for_target:
		# 是的！我们等的就是你！
		# 使用我们之前存好的卡牌，和刚被点击的敌人，打出这张卡
		await play_card(card_ui_pending_target, card_pending_target, enemy_instance)

	else:
		# 玩家只是随便点点敌人，我们不关心
		print("...但我们没有在等待目标。")

func _unhandled_input(event: InputEvent) -> void:
	# 检查：1. 我们是否在瞄准？ 2. 事件是不是鼠标右键按下？
	if is_waiting_for_target and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
		# 是的，玩家按了右键，取消瞄准
		cancel_aiming()
		# 标记事件已被“处理”，防止它继续传递
		get_tree().get_root().set_input_as_handled()

func on_end_turn_pressed():
	print("--- 玩家回合结束 ---")
	# a. 禁用按钮，防止玩家在回合过渡时连点
	end_turn_button.disabled = true
	# b. 弃掉所有手牌
	await discard_hand() # await 关键字会等待函数完成
	# c. 结算玩家回合结束 (清零护甲)
	player.on_turn_end()
	# d. 等待 0.5 秒，让玩家看清护甲消失
	await get_tree().create_timer(0.5).timeout

	# e. 执行敌人回合
	print("--- 敌人回合开始 ---")
	await enemy_turn()

	# f. 等待 0.5 秒，让玩家反应敌人攻击
	await get_tree().create_timer(0.5).timeout

	# g. 开始玩家的新回合
	print("--- 玩家新回合开始 ---")
	start_player_turn()

	# h. 重新启用按钮
	end_turn_button.disabled = false
# [重构 - 已修复]
func discard_hand():
	print("弃掉所有手牌...")
	for card_data in hand:
		discard_pile.append(card_data)
	hand.clear()
	
	var discard_target_pos = discard_pile_label.get_global_rect().get_center()
	var animation_duration = 0.3
	var delay_between_cards = 0.05 # 每张卡飞走的间隔

	var cards_to_discard = hand_container.get_children()
	
	if cards_to_discard.is_empty():
		update_ui()
		return

	for card_ui in cards_to_discard:
		# [新修复]
		# 1. 我们在这里等待一个短暂的延迟
		#    而不是在 Tween 上设置它
		await get_tree().create_timer(delay_between_cards).timeout
		
		# 2. 脱离 HBoxContainer 的控制
		var start_pos = card_ui.global_position
		card_ui.reparent(hand_container.get_parent()) 
		card_ui.global_position = start_pos 
		
		# 3. 创建一个新 Tween
		var tween = create_tween()
		
		# 4. [已移除] 不再需要 tween.set_delay()
		
		# 5. 并行动画
		tween.set_parallel(true)
		tween.tween_property(card_ui, "global_position", discard_target_pos, animation_duration).set_ease(Tween.EASE_IN)
		tween.tween_property(card_ui, "scale", Vector2.ZERO, animation_duration).set_ease(Tween.EASE_IN)
		
		# 6. 动画结束后，删除卡牌
		tween.chain().tween_callback(card_ui.queue_free)
	
	update_ui()
	
	# [新修复] 我们不再需要复杂的总时间计算
	# 我们只需要等待最后一张卡牌的动画完成
	await get_tree().create_timer(animation_duration).timeout
# 3. (新函数) 敌人回合的逻辑
func enemy_turn():
	# a. 让敌人执行它的AI
	enemy.do_action()

	# b. 等待1秒钟，模拟敌人“思考”和“攻击动画”
	await get_tree().create_timer(1.0).timeout
	print("敌人结束行动")


# 4. (新函数) 玩家新回合的逻辑
func start_player_turn():
	player.on_turn_start()
	energy = energy_max

	await draw_cards(5) # <--- [添加 AWAIT]


# [新函数]
# 当 enemy 发出 "wants_to_attack" 信号时调用
func on_enemy_attacks(damage: int):
	print("BattleManager 收到敌人 %d 点攻击" % damage)
	player.take_damage(damage)
	
	
	
