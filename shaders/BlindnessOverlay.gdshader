shader_type canvas_item;

uniform vec2 circle_center; // Position of the "clear" circle in screen pixels.
uniform float hole_radius = 100.0; // Radius of the clear circle.
uniform float smoothness = 20.0;   // How gradual the transition is.
uniform float max_opacity = 0.8;   // Maximum opacity (0.0 to 1.0) for the black.

void fragment() {
    // FRAGCOORD.xy gives the pixel coordinate.
    float d = distance(FRAGCOORD.xy, circle_center);
    // smoothstep creates a soft edge: fully transparent inside the circle,
    // and gradually fades to semi-transparent black outside.
    float alpha = smoothstep(hole_radius, hole_radius + smoothness, d) * max_opacity;
    COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
