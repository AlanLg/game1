/*

WELCOME, to the lovely land of shaders.

At some point, you'll find yourself wanting to pull off an effect visually, but don't know how.
Like adding lighting, or making a single sprite flash completely white.

But now, with the full power of core_render.odin at your finger tips, you can adjust the renderer
to suit any pipeline you need for processing shaders, specific to your game.

Be that:
- just modifying the fragment shader directly
- adding new data to the vertex for per-sprite operations (I do this mainly with the Quad_Flags)
- introducing new steps to the pipeline, like maybe rendering to a texture first and doing some processing on it

Anything is possible.

If you'd like to learn more...

Here's the Holy Bible -> https://thebookofshaders.com/

*/


// syntax reference: https://github.com/floooh/sokol-tools/blob/master/docs/sokol-shdc.md
@header #+private package
@header package draw
@header import sg "bald:sokol/gfx"

@ctype vec4 Vec4
@ctype mat4 Matrix4

//
// VERTEX SHADER
//
@vs vs
in vec2 position;
in vec4 color0;
in vec2 uv0;
in vec2 local_uv0;
in vec2 size0;
in vec4 bytes0;
in vec4 color_override0;
in vec4 params0;

out vec4 color;
out vec2 uv;
out vec2 local_uv;
out vec2 size;
out vec4 bytes;
out vec4 color_override;
out vec4 params;

out vec2 pos;

void main() {
	gl_Position = vec4(position, 0, 1);
	color = color0;
	uv = uv0;
	local_uv = local_uv0;
	bytes = bytes0;
	color_override = color_override0;
	size = size0;
	params = params0;
	
	pos = gl_Position.xy;
}
@end


//
// FRAGMENT SHADER
//
@fs fs

layout(binding=0) uniform texture2D tex0;
layout(binding=1) uniform texture2D font_tex;

layout(binding=0) uniform sampler default_sampler;

layout(binding=0) uniform CBuff {
	mat4 ndc_to_world_xform;
};

in vec4 color;
in vec2 uv;
in vec2 local_uv;
in vec2 size;
in vec4 bytes;
in vec4 color_override;
in vec4 params;

in vec2 pos;

out vec4 col_out;

@include shader_utils.glsl

// #shared with Quad_Flags definition (name doesn't matter, just value)
#define FLAG_background_pixels (1<<0)
#define FLAG_2 (1<<1)
#define FLAG_3 (1<<2)
bool has_flag(int flags, int flag) { return (flags & flag) != 0; }

// const data
layout(binding=1) uniform Const_Shader_Data {
	vec4 bg_repeat_tex0_atlas_uv;
};

void main() {

	int tex_index = int(bytes.x * 255.0);

	int flags = int(bytes.z * 255.0);

	vec2 world_pixel = (ndc_to_world_xform * vec4(pos.xy, 0, 1)).xy;
	
	vec4 tex_col = vec4(1.0);
	if (tex_index == 0) {
		tex_col = texture(sampler2D(tex0, default_sampler), uv);
	} else if (tex_index == 1) {
		// this is text, it's only got the single .r channel so we stuff it into the alpha
		tex_col.a = texture(sampler2D(font_tex, default_sampler), uv).r;
	}
	
	col_out = tex_col;

	if (has_flag(flags, FLAG_background_pixels)) {
		float wrap_length = 128.0;
		vec2 uv = world_pixel / wrap_length;
		uv = local_uv_to_atlas_uv(uv, bg_repeat_tex0_atlas_uv);
		vec4 img = texture(sampler2D(tex0, default_sampler), uv);
		col_out.rgb = img.rgb;
	}

	// add :pixel stuff here ^
	
	col_out *= color;
	
	col_out.rgb = mix(col_out.rgb, color_override.rgb, color_override.a);
	
}
@end

@program quad vs fs