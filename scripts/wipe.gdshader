shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 center = vec2(0.5, 0.5);
uniform vec3 fade_color : source_color = vec3(0.0, 0.0, 0.0);
uniform float aspect_ratio = 1.778; // 16:9 default

void fragment() {
    vec2 uv = UV;
    
    // Correct for aspect ratio so the iris is a circle, not an ellipse
    vec2 centered = uv - center;
    centered.x *= aspect_ratio;
    
    float dist = length(centered);
    
    // Max possible distance from center (corner of screen)
    float max_dist = length(vec2(0.5 * aspect_ratio, 0.5));
    
    // Iris radius based on progress (0 = fully open, 1 = fully closed)
    float iris_radius = (1.0 - progress) * max_dist * 1.05; // slight overshoot to fully black
    
    float edge_softness = 0.008;
    float alpha = smoothstep(iris_radius - edge_softness, iris_radius + edge_softness, dist);
    
    COLOR = vec4(fade_color, alpha);
}