# scripts/battle/battle.gd
extends Node2D

# -------- 预加载资源 --------
# 预加载“卡牌UI”场景。我们必须先加载它，才能在代码里“实例化”它。
const CardUI_Scene = preload("res://scenes/ui/card_ui.tscn")

# 预加载我们的卡牌“数据”。
const BasicStrike_Data = preload("res://data/cards/basic_strike.tres")
const BasicDefend_Data = preload("res://data/cards/basic_defend.tres")


# -------- 节点引用 --------
# 引用UI，以便更新它们
@onready var hand_container: HBoxContainer = $UI_Layer/BattleUI/HandContainer
@onready var draw_pile_label: Label = $UI_Layer/BattleUI/PileContainer/DrawPileLabel
@onready var discard_pile_label: Label = $UI_Layer/BattleUI/PileContainer/DiscardPileLabel
@onready var energy_label: Label = $UI_Layer/BattleUI/EnergyLabel
@onready var aiming_arrow: Line2D = $AimingArrow
@onready var player: Node2D = $Player
@onready var enemy: Area2D = $Enemy 

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
	draw_cards(5)


# 2. 抽卡
func draw_cards(amount: int):
	for i in range(amount):
		# a. 检查抽牌堆是否为空？
		if draw_pile.is_empty():
			# b. 如果是，则将弃牌堆洗回抽牌堆
			shuffle_discard_into_draw_pile()
			
			# c. 如果洗完还是空的 (说明玩家没牌了)，就停止抽卡
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
		# [新代码] 连接这个新实例的 "card_clicked" 信号
		# 到我们自己的 "on_card_clicked" 函数上
		card_ui_instance.card_clicked.connect(on_card_clicked)
		
		# h. 把实例化的卡牌UI，作为子节点添加到 HandContainer 中
		hand_container.add_child(card_ui_instance)
	
	# 抽完卡后，更新一下UI
	update_ui()


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
			play_card(card_ui, card_data, null) # null 表示没有目标

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
	card_ui.queue_free()

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
		if target: # 确保有目标 (target 就是 enemy)
			# [修改] 不再打印，而是调用函数
			target.take_damage(card_data.damage)
		else:
			print("错误：攻击卡没有目标！") 
			
	if card_data.block > 0:
		# [修改] 护甲是给玩家的
		player.add_block(card_data.block)
		
# 当任何一个在 "enemies" 分组的节点发出 "enemy_clicked" 信号时调用
func on_enemy_clicked(enemy_instance: Node2D):
	print("BattleManager 监听到敌人被点击: ", enemy_instance.name)

	# 检查我们是否在等待目标
	if is_waiting_for_target:
		# 是的！我们等的就是你！
		# 使用我们之前存好的卡牌，和刚被点击的敌人，打出这张卡
		play_card(card_ui_pending_target, card_pending_target, enemy_instance)

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
	
