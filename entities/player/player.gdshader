shader_type canvas_item;

uniform vec4 glow_color;
uniform float blur_amount = 0.5;

void fragment() {
    vec4 base_color = texture(TEXTURE, UV);
    vec4 glow = base_color * glow_color;

    // Simple bloom effect by spreading color
    float blur = blur_amount * length(UV - vec2(0.5));
    glow.rgb += glow_color.rgb * smoothstep(1.0, 0.0, blur);

    COLOR = glow;
}
