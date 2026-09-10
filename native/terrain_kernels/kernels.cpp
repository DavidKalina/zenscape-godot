#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <algorithm>
#include <cmath>

using namespace godot;

// Pure numerical work. No Object property reads, scene operations, renderer or
// physics calls occur in the loop. GDScript owns input snapshots and publication.
class ZenScapeTerrainKernels : public RefCounted {
    GDCLASS(ZenScapeTerrainKernels, RefCounted)
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("shade", "inputs", "arrays", "faces", "water", "first", "last"), &ZenScapeTerrainKernels::shade);
    }
public:
    Dictionary shade(const Dictionary &p, const Array &arrays, const PackedInt32Array &faces,
                     const Dictionary &water, int first, int last) const {
        // Keep scalar arithmetic double where GDScript uses float, and Vector/
        // Color arithmetic float where Godot's builtin methods use real_t.
        PackedVector3Array vertices = arrays[0]; vertices = vertices.duplicate();
        PackedVector3Array normals = arrays[1]; normals = normals.duplicate();
        PackedColorArray colors = arrays[3]; colors = colors.duplicate();
        PackedVector2Array uv2 = arrays[5]; uv2 = uv2.duplicate();
        const PackedFloat32Array heights = p["heights"], grass = p["grass"], meadow = p["meadow"], tint = p["tint"], recipe_heights = p["_recipe_heights"];
        const PackedInt32Array ids = p["vertex_ids"], probes = p["_face_probe"], locate = p["_locate_face"];
        const PackedFloat64Array xs = p["_face_x"], zs = p["_face_z"], shimmer = p["_face_shimmer"], us = p["_locate_u"], vs = p["_locate_v"];
        const PackedColorArray greens = p["_face_grass"], rocks = p["_face_rock"], snows = p["_face_snow"], source_colors = p["source_colors"];
        const PackedByteArray rims = p["_face_rim"];
        const Array gradients = p["_recipe_gradients"];
        const bool blank = p["blank"], has_recipe = p["has_recipe"], sculpted = p["sculpted"];
        const double snowline = p["snowline"], rock_slope = p["rock_slope"];
        const Color ground = p["_ground_tint"], sand = p["sand"], gravel = p["gravel"];
        const bool paints_uv2 = uv2.size() == vertices.size();
        const bool wet = !water.is_empty();
        const PackedFloat32Array shore = wet ? PackedFloat32Array(water["shore"]) : PackedFloat32Array();
        const PackedFloat32Array depth = wet ? PackedFloat32Array(water["depth"]) : PackedFloat32Array();
        const PackedByteArray kind = wet ? PackedByteArray(water["kind"]) : PackedByteArray();
        auto grid = [](const PackedFloat32Array &values, double x, double z) {
            const double fi = std::clamp((x+14.0)/(28.0/51), 0.0, 51.0);
            const double fj = std::clamp((z+14.0)/(28.0/51), 0.0, 51.0);
            const int i = std::min(50, int(std::floor(fi))), j = std::min(50, int(std::floor(fj)));
            const double u = fi-i, v = fj-j;
            const int k = j*52+i;
            return values[k]*(1-u)*(1-v)+values[k+1]*u*(1-v)+values[k+52]*(1-u)*v+values[k+53]*u*v;
        };
        auto delta = [&](int slot) {
            const int i = locate[slot];
            if (i < 0) return 0.0;
            const double u = us[slot], v = vs[slot];
            const int a = ids[i], b = ids[i+1], c = ids[i+2];
            return (u*heights[a]+v*heights[b]+(1.0-u-v)*heights[c])-(u*recipe_heights[a]+v*recipe_heights[b]+(1.0-u-v)*recipe_heights[c]);
        };
        for (int f = 0; f < faces.size(); ++f) {
            const int i = faces[f];
            if (i < first || i >= last) continue;
            for (int j = 0; j < 3; ++j) {
                Vector3 v = vertices[i+j]; v.y = heights[ids[i+j]]; vertices.set(i+j, v);
                if (paints_uv2) { Vector2 uv = uv2[i+j]; uv.y = v.y; uv2.set(i+j, uv); }
            }
            const Vector3 normal = (vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i]).normalized();
            const Vector3 center = (vertices[i]+vertices[i+1]+vertices[i+2])/3.0f;
            const int face = i/3;
            const double x = xs[face], z = zs[face];
            const Vector2 meadow_grid = (Vector2(center.x, center.z)+Vector2(14,14))/0.5f;
            const int cell = std::clamp(int(meadow_grid.y), 0, 55)*56+std::clamp(int(meadow_grid.x), 0, 55);
            const double coverage = blank ? std::max(grass[cell], meadow[cell]) : grass[cell];
            Color color = ground.lerp(greens[face], float(coverage));
            bool snowed = false;
            if (blank) {
                const double ny = normal.y;
                double slope = std::sqrt(std::max(0.0, 1.0-ny*ny))/std::max(ny, 0.001);
                if (has_recipe) {
                    Vector2 gradient = gradients[face];
                    if (sculpted) {
                        const int probe = face*4;
                        gradient += Vector2((delta(probes[probe])-delta(probes[probe+1]))/0.5,
                                            (delta(probes[probe+2])-delta(probes[probe+3]))/0.5);
                    }
                    slope = gradient.length();
                }
                if (center.y > snowline-1.8 || (slope > rock_slope && (rims[face] != 1 || has_recipe))) color = rocks[face];
                if (center.y > snowline && slope < 2.4) { color = snows[face]; snowed = true; }
                if (wet) {
                    const double distance = grid(shore, x, z);
                    const int col = int(std::floor((x+14.0)/(28.0/51)+0.5)), row = int(std::floor((z+14.0)/(28.0/51)+0.5));
                    const bool running = col >= 0 && row >= 0 && col < 52 && row < 52 && kind[row*52+col] == 2;
                    if (running && distance < 1.7 && center.y < snowline-1.8) color = greens[face];
                    if (distance < 0.75 && slope < 2.2) {
                        Color bank = running ? gravel : sand;
                        if (distance < -0.05) bank *= float(0.78-0.16*std::min(1.0, grid(depth, x, z)));
                        color = Color(double(bank.r)+shimmer[face], double(bank.g)+shimmer[face], double(bank.b)+shimmer[face]);
                    }
                }
            } else color = source_colors[i].lerp(greens[face], float(coverage));
            const double painted = snowed ? 0.0 : tint[cell*4+3];
            if (painted > 0) {
                const int k = cell*4;
                const Color target(tint[k]+shimmer[face], tint[k+1]+shimmer[face], tint[k+2]+shimmer[face]);
                color = color.lerp(target, float(std::min(painted, 1.0)));
            }
            for (int j = 0; j < 3; ++j) {
                normals.set(i+j, normal);
                colors.set(i+j, (blank || coverage > 0 || painted > 0) ? color : source_colors[i+j]);
            }
        }
        Dictionary result;
        result["vertices"] = vertices.slice(first,last);
        result["normals"] = normals.slice(first,last);
        result["uv2"] = uv2.slice(first,last);
        result["colors"] = colors.slice(first,last);
        return result;
    }
};

static void initialize(ModuleInitializationLevel level) {
    if (level == MODULE_INITIALIZATION_LEVEL_SCENE) ClassDB::register_class<ZenScapeTerrainKernels>();
}
extern "C" GDExtensionBool GDE_EXPORT zenscape_kernels_init(GDExtensionInterfaceGetProcAddress get_proc,
        GDExtensionClassLibraryPtr library, GDExtensionInitialization *initialization) {
    GDExtensionBinding::InitObject init(get_proc, library, initialization);
    init.register_initializer(initialize);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init.init();
}
