// Balanço de junco (addendum v3.1 §G.2): pé cravado, topo balançando —
// amplitude quadrática pela altura. AMPLITUDE INTEIRA em pixels (§J do
// v3.1): fracionária vira tremulação; com snap_2d_vertices_to_pixel ON a
// Godot arredonda o resto.
// `fase` é por touceira: sem ela os 400px balançam em uníssono — o mesmo
// defeito de uniformidade que o addendum manda quebrar.
shader_type canvas_item;

uniform float amplitude = 1.0;      // px, inteira
uniform float freq = 1.1;
uniform float fase = 0.0;

void vertex() {
	float base = 1.0 - UV.y;        // 0 no pé, 1 no topo
	VERTEX.x += sin(TIME * freq + fase) * amplitude * base * base;
}
