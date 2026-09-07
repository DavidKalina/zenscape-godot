extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(64,64)
	root.content_scale_size = Vector2i(64,64)
	var rect := ColorRect.new()
	rect.size = Vector2(64,64)
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
#include "res://shaders/reference_lake_lighting.gdshaderinc"
uniform vec3 eye;
uniform vec3 sun;
uniform vec3 state;
void fragment() { COLOR = vec4(zs_lake_ice_highlight(vec3(0,1,0),eye,sun,vec3(0.2,0.15,0.1),state),1); }
"""
	material.shader = shader
	rect.material = material
	root.add_child(rect)
	var eye := Vector3(0,0.7,sqrt(0.51))
	material.set_shader_parameter("eye",eye)
	for cover in [0.0,0.4,1.0]:
		for clear in [0.0,1.0]:
			for snow in [0.0,0.5,1.0]:
				for offset in [0.0,0.3]:
					var sun := Vector3(offset,eye.y,-eye.z).normalized()
					material.set_shader_parameter("sun",sun)
					material.set_shader_parameter("state",Vector3(cover,clear,snow))
					for frame in range(3):
						RenderingServer.force_draw(false)
						await process_frame
					var pixel := root.get_texture().get_image().get_pixel(32,32)
					var nh := maxf(0,Vector3.UP.dot((eye+sun).normalized()))
					var gloss: float = 32+388*clear
					var amplitude: float = (gloss+2)/8*pow(nh,gloss)*maxf(sun.y,0)*(0.025+0.975*pow(1-eye.y,5))*(1-snow)*cover
					var expected := Vector3(0.2,0.15,0.1)*amplitude
					if Vector3(pixel.r,pixel.g,pixel.b).distance_to(expected)>0.01:
						failures += 1
						push_error("Ice highlight differs from source: " + str(pixel) + " expected " + str(expected))
	rect.queue_free()
	await process_frame
	print("PASS: source ice highlight across coverage, clear/frost, snow and viewing angles" if failures == 0 else "FAIL: ice highlight")
	quit(1 if failures else 0)
