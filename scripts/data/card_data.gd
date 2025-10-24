# scripts/data/card_data.gd
@tool
extends Resource
class_name CardData

# 定义卡牌的类型（用我们的主题）
# enum 是一种“枚举”，让我们可以在编辑器里下拉选择
enum CardType {
	ZHAO_SHI,   # 招式 (主要用于攻击)
	XIN_FA,     # 心法 (主要用于防御、Buff、抽卡)
	DAN_YAO,    # 丹药 (消耗品，一次性强力效果)
	JUE_JI      # 绝技 (高消耗、高回报)
}

# -------- 基础信息 --------
# @export 会把这个变量显示在Godot的“检查器”面板里
@export var id: String = "unique_card_id"           # 唯一ID，用于程序识别
@export var title: String = "卡牌标题"                # 显示的标题，如 "基础拳法"
@export_multiline var description: String = "卡牌描述" # 多行文本的描述
@export var cost: int = 1                           # 灵力/能量 消耗

@export var card_type: CardType = CardType.ZHAO_SHI # 卡牌类型
@export var card_art: Texture2D                     # 卡牌插画 (现在是色块，以后换成AI图)

# -------- 核心效果 --------
# 我们先用简单的方式，只定义几个关键数字
@export_group("效果数值") # 在检查器中创建一个分组
@export var damage: int = 0                         # 造成的伤害
@export var block: int = 0                          # 提供的护甲 (真气护体)
@export var draw: int = 0                           # 抽几张牌
# ... 以后可以加更多, 比如 "中毒", "易伤" 等

# -------- 创新系统的预留字段 --------
@export_group("合成与升级")
@export var level: int = 1                          # 卡牌等级 (用于 A + A = A+)
@export var fusion_group: String = ""               # 合成组 (如 "火系", "拳法")
													# "火系" + "拳法" = "火焰拳"
# @export var upgrade_target: Resource # 暂时注释掉，未来再加
