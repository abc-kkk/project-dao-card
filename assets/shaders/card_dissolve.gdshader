// assets/shaders/card_dissolve.gdshader
shader_type canvas_item;
render_mode blend_mix, unshaded; 

// --- uniforms ---
uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D noise_texture : filter_linear, repeat_enable;
uniform vec4 glow_color : source_color = vec4(1.0, 0.5, 0.0, 1.0);
uniform float tiling = 5.0; // 调整噪点平铺

// [已删除]
// 我们不再需要 vertex() 函数
// 我们不再需要 v_world_pos
// 我们不再需要 noise_scale

// [已修复]
// fragment() 函数
void fragment() {
	// 1. [已修复]
	//    我们不再需要 texture(TEXTURE, UV)
	//    我们使用 "SCREEN_UV"，这是最稳妥的
	vec2 noise_uv = SCREEN_UV * tiling; 
	float noise = texture(noise_texture, noise_uv).r;
	
	// 2. (逻辑保持不变)
	float edge_width = 0.05;
	float dissolve_mask = smoothstep(dissolve_amount, dissolve_amount + edge_width, noise);
	float glow_mask = smoothstep(dissolve_amount - edge_width, dissolve_amount, noise) - dissolve_mask;

	// 3. [已修复]
	//    "COLOR" 是内置变量，包含了原始颜色 (比如蓝色色块)
	//    我们把它乘以"溶解蒙版"来让它消失
	//    然后再加上"发光蒙版"乘以"发光颜色"
	COLOR = (COLOR * dissolve_mask) + (glow_color * glow_mask);
}