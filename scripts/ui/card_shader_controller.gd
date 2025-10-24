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
var nine_patch_rect: NinePatchRect
var shader_material: ShaderMaterial

func _ready():
	# 获取NinePatchRect节点
	nine_patch_rect = get_parent().get_node("NinePatchRect")
	
	# 获取现有的shader material
	shader_material = nine_patch_rect.material as ShaderMaterial
	
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
