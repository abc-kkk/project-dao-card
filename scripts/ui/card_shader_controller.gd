# scripts/ui/card_shader_controller.gd
extends Node

# 溶解效果的shader控制
@export var dissolve_amount: float = 0.0:
	set(value):
		dissolve_amount = clamp(value, 0.0, 1.0)
		update_shader()

@export var glow_color: Color = Color(1, 0.5, 0, 1):
	set(value):
		glow_color = value
		update_shader()

@export var tiling: float = 5.0:
	set(value):
		tiling = value
		update_shader()

# 引用需要应用shader的节点
var visuals_group: CanvasGroup
var shader_material: ShaderMaterial

func _ready():
	# 获取VisualsGroup节点
	visuals_group = get_parent().get_node("VisualsGroup")
	
	# 创建shader material
	shader_material = ShaderMaterial.new()
	shader_material.shader = load("res://assets/shaders/card_dissolve.gdshader")
	
	# 应用shader到VisualsGroup
	visuals_group.material = shader_material
	
	# 初始化shader参数
	update_shader()

func update_shader():
	if shader_material:
		shader_material.set_shader_parameter("dissolve_amount", dissolve_amount)
		shader_material.set_shader_parameter("glow_color", glow_color)
		shader_material.set_shader_parameter("tiling", tiling)

# 溶解动画
func dissolve_in(duration: float = 0.5):
	var tween = create_tween()
	tween.tween_method(set_dissolve_amount, 1.0, 0.0, duration)

func dissolve_out(duration: float = 0.5):
	var tween = create_tween()
	tween.tween_method(set_dissolve_amount, 0.0, 1.0, duration)

func set_dissolve_amount(value: float):
	dissolve_amount = value
