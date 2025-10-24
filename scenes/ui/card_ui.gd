# scripts/ui/card_ui.gd
@tool
extends Control

# [新代码] 定义一个信号，当卡牌被点击时发出
# 它会把自己（CardUI 实例）和自己的数据（CardData）一起广播出去
signal card_clicked(card_ui,card_data)

# --- 节点引用 (你的路径是正确的) ---
@onready var title_label: Label = $NinePatchRect/MarginContainer/VBoxContainer/Title
@onready var art_rect: ColorRect = $NinePatchRect/MarginContainer/VBoxContainer/Art
@onready var description_label: RichTextLabel = $NinePatchRect/MarginContainer/VBoxContainer/Description
@onready var cost_label: Label = $Cost

# --- 核心变量 ---
var data: CardData:
	set(new_data):
		data = new_data
		
		# [THE FIX - Part 1]
		# 检查节点是否已经“准备就绪”
		# 如果 @onready 变量还没被赋值 (即 _ready 还没跑), 
		# 我们就不调用 update_display(), 避免 'Nil' 错误
		if is_node_ready():
			if data:
				update_display()
			else:
				clear_display()

# --- 函数 ---

func update_display():
	# (确保 title_label 不是 Nil)
	if not title_label:
		return # 预防万一

	title_label.text = data.title
	cost_label.text = str(data.cost)
	
	var desc_text = data.description
	desc_text = desc_text.replace("{damage}", str(data.damage))
	desc_text = desc_text.replace("{block}", str(data.block))
	description_label.text = desc_text
	
	match data.card_type:
		CardData.CardType.ZHAO_SHI:
			art_rect.color = Color.FIREBRICK
		CardData.CardType.XIN_FA:
			art_rect.color = Color.ROYAL_BLUE
		_:
			art_rect.color = Color.GRAY

func clear_display():
	if not title_label:
		return
		
	title_label.text = ""
	cost_label.text = ""
	art_rect.color = Color.BLACK
	description_label.text = ""


# ... (你其他的 clear_display, _ready 等函数) ...

# [新函数]
# 这是一个 Control 节点的内置函数
# 当鼠标事件在 CardUI 区域内发生时，它会被调用
func _gui_input(event: InputEvent):
	# 1. 检查事件是不是“鼠标左键按下”
	# 2. 并且检查我们是不是在游戏里 (而不是在编辑器里误点)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if not Engine.is_editor_hint():
			# 3. 发出我们定义的信号！
			#    把自己 (self) 和自己的数据 (data) 传出去
			print("卡牌被点击: ", data.title) # 用于调试
			emit_signal("card_clicked", self, data)

# --- Godot 核心函数 ---
func _ready():
	# @onready 变量在此刻刚刚被赋值
	# 处理编辑器预览
	if Engine.is_editor_hint():
		var test_card = load("res://data/cards/basic_strike.tres")
		if test_card:
			self.data = test_card # 此时 is_node_ready() 是 true, setter会直接更新
	
	# [THE FIX - Part 2]
	# 处理游戏内加载
	else:
		# 检查 data 是否在 _ready() 运行前就"提前"被赋值了
		# 如果是, setter 会跳过 update_display(), 所以我们在这里补上
		if data:
			update_display()
			
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

# [新函数] 当鼠标进入卡牌区域时调用
func _on_mouse_entered():
	# 仅在游戏中执行 (防止在编辑器里触发)
	if Engine.is_editor_hint():
		return
		
	# 1. 把自己提到最上层
	z_index = 10
	
	# 2. 创建一个补间动画 (Tween)
	var tween = create_tween()
	
	# 3. 让 "scale" (缩放) 属性在 0.1 秒内
	#    从当前值 变到 Vector2(1.5, 1.5)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)

# [新函数] 当鼠标离开卡牌区域时调用
func _on_mouse_exited():
	if Engine.is_editor_hint():
		return
		
	# 1. 恢复 Z 轴
	z_index = 0
	
	# 2. 创建一个补间动画
	var tween = create_tween()
	
	# 3. 让 "scale" 属性在 0.1 秒内
	#    恢复到 Vector2(1.0, 1.0)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
