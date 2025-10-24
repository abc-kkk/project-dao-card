// assets/shaders/aiming_arrow.gdshader
shader_type canvas_item;

// [关键] 开启"相加"混合模式，让它发光
render_mode blend_add;

// --- 参数 ---
uniform vec4 line_color : source_color = vec4(1.0, 0.0, 0.0, 1.0); // 纯红
uniform float glow_strength : hint_range(0.0, 2.0) = 0.8; // 发光强度
uniform float scroll_speed : hint_range(-2.0, 2.0) = 0.5; // 滚动速度
uniform sampler2D noise_texture : filter_linear;

void fragment() {
	
	// --- 纹理流动 ---
	vec2 scrolled_uv = UV;
	scrolled_uv.x += TIME * scroll_speed;
	float noise = texture(noise_texture, scrolled_uv).r; // .r = 红色通道

	// --- 形状定义 (这是我们修复的地方) ---
	// 我们不再依赖 UV.y，而是自己创造一个形状
	
	// 1. 创建一个沿着线条滚动的"核心"波浪
	//    sin(UV.x * 10.0 + TIME * scroll_speed * 3.0)
	//    pow(..., 4.0) 让波谷变窄，波峰变宽
	float core_wave = pow( (sin(UV.x * 10.0 + TIME * scroll_speed * 3.0) + 1.0) / 2.0, 4.0);
	
	// 2. 用噪点纹理“腐蚀”这个波浪
	float core_alpha = core_wave * noise * 1.5; // 1.5 是增强亮度
	
	// 3. 创建一个简单的“发光”
	//    我们用噪点本身作为发光体，但让它更柔和
	float glow_alpha = noise * glow_strength;
	
	// 4. 最终输出
	COLOR = line_color;
	// 最终透明度 = 核心的透明度 + 发光的透明度
	// clamp 确保透明度不会超过 1.0
	COLOR.a *= clamp(core_alpha + glow_alpha, 0.0, 1.0);
}