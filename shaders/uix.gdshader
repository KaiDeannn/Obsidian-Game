shader_type canvas_item;

void fragment() {
    vec2 centered_uv = UV - vec2(0.5);
    float radius = 0.5;
    float distance_from_center = length(centered_uv);

    float alpha = 1.0 - smoothstep(
        radius - fwidth(distance_from_center),
        radius + fwidth(distance_from_center),
        distance_from_center
    );

    vec4 color = texture(TEXTURE, UV);
    color.a *= alpha;

    COLOR = color;
}