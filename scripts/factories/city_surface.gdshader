// Procedural, world-space (triplanar) surfaces for the ruined city: brick, stone,
// concrete, wood planks, tile, carpet and painted plaster — no texture assets needed.
// The pattern is projected from world position by the dominant face normal, so brick
// courses / tile grids stay a consistent real-world size across every box and align
// from wall to wall.
//
// Two extra modes keep interiors reading correctly:
//   * ceiling_enable: downward-facing faces of a floor slab render a CEILING finish
//     (plaster / exposed concrete / acoustic tile) instead of the floor finish above.
//   * inner_enable: the inward-facing side of an outer wall renders the INTERIOR paint
//     (matching the room dividers), while the outward side keeps its cladding.
shader_type spatial;

uniform int style = 0;            // 0 brick, 1 stone, 2 concrete, 3 planks, 4 paint, 5 tile, 6 carpet
uniform vec3 base_color : source_color = vec3(0.6, 0.32, 0.26);
uniform vec3 line_color : source_color = vec3(0.42, 0.40, 0.38);   // mortar / grout / seam
uniform vec2 cell_size = vec2(0.45, 0.16);   // world metres (unit width, unit height)
uniform float line_frac = 0.06;              // joint thickness as a fraction of a cell
uniform float rough = 0.9;
uniform float stripe = 0.0;                  // 1 = faint wallpaper stripe (style 4)

uniform float ceiling_enable = 0.0;
uniform vec3 ceiling_color : source_color = vec3(0.68, 0.66, 0.62);
uniform int ceiling_style = 0;               // 0 plaster, 1 exposed concrete, 2 acoustic tile
uniform float inner_enable = 0.0;
uniform vec3 inner_color : source_color = vec3(0.80, 0.78, 0.74);
uniform float inner_stripe = 0.0;
uniform vec3 building_center = vec3(0.0);

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	// Triplanar: pick the 2D coordinate plane from the dominant face normal.
	vec3 an = abs(wnorm);
	vec2 uv;
	if (an.y >= an.x && an.y >= an.z) {
		uv = wpos.xz;                 // horizontal surfaces (floors / ceilings)
	} else if (an.x >= an.z) {
		uv = vec2(wpos.z, wpos.y);    // walls facing X
	} else {
		uv = vec2(wpos.x, wpos.y);    // walls facing Z
	}

	vec3 col;
	float r;
	bool handled = false;

	// Ceiling: a downward-facing slab face gets a ceiling finish, never the floor above.
	if (ceiling_enable > 0.5 && wnorm.y < -0.5) {
		if (ceiling_style == 2) {                  // acoustic drop-tile grid
			vec2 fcell = fract(uv / vec2(0.62, 0.62));
			float g = step(0.04, fcell.x) * step(fcell.x, 0.96) * step(0.04, fcell.y) * step(fcell.y, 0.96);
			col = mix(ceiling_color * 0.78, ceiling_color, g);
			r = 0.9;
		} else if (ceiling_style == 1) {           // exposed concrete
			float n = vnoise(uv * 1.6) * 0.6 + vnoise(uv * 7.0) * 0.4;
			col = ceiling_color * (0.80 + 0.30 * n);
			r = 0.95;
		} else {                                   // plaster
			float n = vnoise(uv * 1.8) * 0.7 + vnoise(uv * 5.0) * 0.3;
			col = ceiling_color * (0.92 + 0.10 * n);
			r = 0.85;
		}
		handled = true;
	} else if (inner_enable > 0.5) {
		// Inward face of an outer wall -> interior paint (matches the dividers).
		vec3 outd = normalize(vec3(wpos.x - building_center.x, 0.0, wpos.z - building_center.z));
		if (dot(wnorm, outd) < -0.3) {
			float n = vnoise(uv * 2.2);
			col = inner_color * (0.94 + 0.10 * n);
			col *= 1.0 - 0.06 * inner_stripe * (0.5 + 0.5 * sin(uv.x * 12.566));
			r = 0.65;
			handled = true;
		}
	}

	if (!handled) {
		col = base_color;
		r = rough;
		if (style == 2) {
			// concrete: blotchy two-octave value noise
			float n = vnoise(uv * 1.6) * 0.6 + vnoise(uv * 7.0) * 0.4;
			col = base_color * (0.82 + 0.30 * n);
		} else if (style == 4) {
			// painted plaster, optionally a faint vertical wallpaper stripe
			float n = vnoise(uv * 2.2);
			col = base_color * (0.94 + 0.10 * n);
			col *= 1.0 - 0.06 * stripe * (0.5 + 0.5 * sin(uv.x * 12.566));
		} else if (style == 6) {
			// carpet: flat colour with a fine fibre speckle
			float n = vnoise(uv * 55.0) * 0.5 + vnoise(uv * 130.0) * 0.5;
			col = base_color * (0.90 + 0.16 * n);
			r = 1.0;
		} else {
			// cell-based: brick(0), stone(1), planks(3), tile(5)
			vec2 cs = cell_size;
			float bond = (style == 0 || style == 1 || style == 3) ? 0.5 : 0.0;  // running / staggered bond
			float row = floor(uv.y / cs.y);
			float offset = mod(row, 2.0) * bond * cs.x;
			float bxc = uv.x + offset;
			float coli = floor(bxc / cs.x);
			vec2 fc = vec2(fract(bxc / cs.x), fract(uv.y / cs.y));
			float face = step(line_frac, fc.x) * step(fc.x, 1.0 - line_frac)
				* step(line_frac, fc.y) * step(fc.y, 1.0 - line_frac);
			float h = hash21(vec2(coli, row));
			vec3 unit = base_color * (0.80 + 0.40 * h);
			if (style == 1) {
				unit *= 0.70 + 0.60 * vnoise(vec2(coli, row) * 1.3 + uv * 0.3);   // irregular stone tone
			} else if (style == 3) {
				unit *= 0.85 + 0.30 * vnoise(vec2(uv.x * 7.0, coli * 11.0));      // plank grain
			} else if (style == 5) {
				unit = base_color * (0.90 + 0.20 * h);                            // even tile tone
			}
			col = mix(line_color, unit, face);
			r = mix(0.96, rough, face);
		}
	}

	ALBEDO = col;
	ROUGHNESS = clamp(r, 0.0, 1.0);
	METALLIC = 0.0;
}
