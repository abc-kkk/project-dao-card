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


# -------- 战斗状态变量 --------
# 我们用数组(Array)来管理卡牌“数据”(CardData)，而不是卡牌“场景”(CardUI)
var deck: Array[CardData] = []         # 玩家的总牌库
var draw_pile: Array[CardData] = []    # 抽牌堆
var hand: Array[CardData] = []         # 手牌 (只存数据)
var discard_pile: Array[CardData] = [] # 弃牌堆

var energy: int = 3
var energy_max: int = 3


# -------- Godot 核心函数 --------
# 当场景启动时，自动调用
func _ready():
	start_battle()


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

# 当任何一张 CardUI 发出 "card_clicked" 信号时，这个函数会被调用
# 它会收到 CardUI 传过来的两个参数
func on_card_clicked(card_ui: Control, card_data: CardData):
	print("BattleManager 收到: ", card_data.title)

	# 1. 检查能量
	if energy >= card_data.cost:
		# 2. 能量足够，执行出牌
		print("能量足够，打出 ", card_data.title)

		# a. 扣除能量
		energy -= card_data.cost

		# b. 执行效果 (暂时只打印)
		apply_card_effect(card_data)

		# c. 将卡牌“数据”从手牌数组(hand)移到弃牌堆数组(discard_pile)
		hand.erase(card_data)
		discard_pile.append(card_data)

		# d. 【重要】从场景中删除这张卡牌的“UI”
		card_ui.queue_free() # queue_free 是最安全的删除节点方式

		# e. 更新UI
		update_ui()

	else:
		# 3. 能量不足
		print("能量不足！需要 ", card_data.cost, " 但只有 ", energy)
		# (以后可以在这里做一个“卡牌抖动”的提示)


# [新函数]
# 一个临时的效果处理函数
func apply_card_effect(card_data: CardData):
	if card_data.damage > 0:
		print("对敌人造成 %d 点伤害" % card_data.damage)
		# (以后这里会连接到 EnemyPlaceholder)

	if card_data.block > 0:
		print("玩家获得 %d 点真气" % card_data.block)
		# (以后这里会连接到 PlayerPlaceholder)
