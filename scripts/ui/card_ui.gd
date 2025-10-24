# scripts/ui/card_ui.gd
@tool
extends Control

# 我们需要"引用"场景中的节点，以便给它们赋值
@onready var title_label: Label = $NinePatchRect/MarginContainer/VBoxContainer/Title
@onready var art_rect: ColorRect = $NinePatchRect/MarginContainer/VBoxContainer/Art
@onready var description_label: RichTextLabel = $NinePatchRect/MarginContainer/VBoxContainer/Description
@onready var cost_label: Label = $Cost
@onready var nine_patch_rect: NinePatchRect = $NinePatchRect

# Shader控制器
var shader_controller: Node

# 关键！这个变量用来"持有"卡牌的数据
# 当我们设置这个变量时，卡牌UI会自动更新
var data: CardData:
	set(new_data):
		data = new_data
		if data:
			update_display()
		else:
			clear_display()

# 当 card_data 被设置时，这个函数会被调用
func update_display():
	title_label.text = data.title
	cost_label.text = str(data.cost)
	art_rect.texture = data.card_art
	
	# 简单的描述替换 (以后会升级)
	# 比如把 "造成 {damage} 点伤害" 替换成 "造成 6 点伤害"
	var desc_text = data.description
	desc_text = desc_text.replace("{damage}", str(data.damage))
	desc_text = desc_text.replace("{block}", str(data.block))
	
	description_label.text = desc_text
	# 我们暂时没有美术，先根据卡牌类型改变 Art 色块的颜色
	match data.card_type:
		CardData.CardType.ZHAO_SHI:
			art_rect.color = Color.FIREBRICK # 红色 (招式)
		CardData.CardType.XIN_FA:
			art_rect.color = Color.ROYAL_BLUE # 蓝色 (心法)
		_:
			art_rect.color = Color.GRAY # 灰色 (其他)

func clear_display():
	title_label.text = ""
	cost_label.text = ""
	art_rect.texture = null
	description_label.text = ""
	
# --- Shader控制方法 ---
func setup_shader_controller():
	# 创建shader控制器
	shader_controller = preload("res://scripts/ui/card_shader_controller.gd").new()
	add_child(shader_controller)

func dissolve_in(duration: float = 0.5):
	if shader_controller:
		shader_controller.dissolve_in(duration)

func dissolve_out(duration: float = 0.5):
	if shader_controller:
		shader_controller.dissolve_out(duration)

# --- 编辑器预览 (关键!) ---
# Godot 的特殊函数，只在编辑器中运行
func _ready():
	# 设置shader控制器
	setup_shader_controller()
	
	# 检查代码是否在编辑器中运行，而不是在游戏里
	if Engine.is_editor_hint():
		# 尝试加载我们的测试卡牌
		# (确保你的路径是 "res://data/cards/basic_strike.tres")
		var test_card = load("res://data/cards/basic_strike.tres")
		if test_card:
			# 触发 set(new_data) 函数，让卡牌在编辑器里就显示出来！
			self.data = test_card
