/*
* This shader creates a glowing effect around the player.
* It is used to create a glowing halo around the player.
*/
shader_type canvas_item;

// Editable properties that can be changed in the editor
uniform float glow_spread : hint_range(0.0, 1.0) = 0.5; // The spread of the glow
uniform float glow_intensity : hint_range(0.0, 2.0) = 1.5; // The intensity of the glow
uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 0.1, 1.0); // The color of the glow

// The vertex function is called for each vertex of the mesh
void fragment() {
    vec2 uv_centered = UV - vec2(0.5);
    float distance = length(uv_centered);
    float glow = smoothstep(glow_spread, 0.0, distance);
    COLOR = vec4(glow_color.rgb, glow_color.a * glow * glow_intensity);
}
