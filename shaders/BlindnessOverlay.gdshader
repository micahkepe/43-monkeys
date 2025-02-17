shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform vec2 circle_center; // Position of the "clear" circle in screen pixels.
uniform float hole_radius = 100.0; // Radius of the clear circle.
uniform float smoothness = 20.0;   // How gradual the transition is.
uniform float max_opacity : hint_range(0.0, 1.0) = 1.0;   // Maximum opacity for the black.

void fragment() {
    // Convert normalized SCREEN_UV to actual pixel coordinates.
    vec2 pixel_coord = SCREEN_UV * vec2(textureSize(SCREEN_TEXTURE, 0));
    float d = distance(pixel_coord, circle_center);
    // For d less than hole_radius, smoothstep returns 0 (fully transparent).
    // For d greater than hole_radius + smoothness, it returns 1 (multiplied by max_opacity).
    float alpha = smoothstep(hole_radius, hole_radius + smoothness, d) * (max_opacity + 0.1) ;
    COLOR = vec4(0.0, 0.0, 0.0, alpha);
}