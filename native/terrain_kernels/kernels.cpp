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
#include <cstdint>
#include <vector>
#include "water_flow.h"
#include "isle_kernels.h"
#include "land_field_bind.h"
#include "grass_cell.h"
#include "tree_cell.h"
#include "flight_fx.h"
#include "peak_massif_bind.h"

using namespace godot;

// Pure numerical work. No Object property reads, scene operations, renderer or
// physics calls occur in the loop. GDScript owns input snapshots and publication.
class ZenScapeTerrainKernels : public RefCounted {
    GDCLASS(ZenScapeTerrainKernels, RefCounted)
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("shade", "inputs", "arrays", "faces", "water", "first", "last"), &ZenScapeTerrainKernels::shade);
        ClassDB::bind_method(D_METHOD("erode", "heights", "fixed", "params"), &ZenScapeTerrainKernels::erode);
    }
    // Terrain erosion mirrors scripts/terrain_erosion.gd `erode_reference` op for
    // op: doubles, int64 hashing, only + - * / sqrt floor. No transcendental
    // functions, so saved worlds reproduce on every platform and in GDScript.
    static int64_t hash2(int64_t x, int64_t z, int64_t seed) {
        int64_t h = ((x*73856093) ^ (z*19349663) ^ seed) & 0xffffffffLL;
        h = ((h ^ (h >> 16))*0x45d9f3bLL) & 0xffffffffLL;
        h = ((h ^ (h >> 16))*0x45d9f3bLL) & 0xffffffffLL;
        return h ^ (h >> 16);
    }
    static double corner(int64_t ix, int64_t iz, double dx, double dz, int64_t seed) {
        static const double gx[8] = {1.0, -1.0, 0.0, 0.0, 0.7071067811865476, -0.7071067811865476, 0.7071067811865476, -0.7071067811865476};
        static const double gz[8] = {0.0, 0.0, 1.0, -1.0, 0.7071067811865476, 0.7071067811865476, -0.7071067811865476, -0.7071067811865476};
        const int64_t g = hash2(ix, iz, seed) & 7;
        return gx[g]*dx+gz[g]*dz;
    }
    static double gradient(double x, double z, int64_t seed) {
        const double fx = std::floor(x), fz = std::floor(z);
        const int64_t ix = int64_t(fx), iz = int64_t(fz);
        const double tx = x-fx, tz = z-fz;
        const double u = tx*tx*tx*(tx*(tx*6.0-15.0)+10.0);
        const double v = tz*tz*tz*(tz*(tz*6.0-15.0)+10.0);
        const double a = corner(ix, iz, tx, tz, seed);
        const double b = corner(ix+1, iz, tx-1.0, tz, seed);
        const double c = corner(ix, iz+1, tx, tz-1.0, seed);
        const double d = corner(ix+1, iz+1, tx-1.0, tz-1.0, seed);
        const double top = a+(b-a)*u;
        const double bottom = c+(d-c)*u;
        return top+(bottom-top)*v;
    }
    static double ridged(double x, double z, int64_t seed) {
        double sum = 0.0, amp = 0.5, weight = 1.0, f = 1.0;
        for (int64_t o = 0; o < 3; ++o) {
            double r = 1.0-std::fabs(gradient(x*f, z*f, (seed+o*1013) & 0xffffffffLL))*1.35;
            if (r < 0.0) r = 0.0;
            r = r*r*weight;
            weight = r*2.0;
            if (weight > 1.0) weight = 1.0;
            sum += r*amp;
            amp *= 0.5;
            f *= 2.03;
        }
        return sum/0.875;
    }
    static double ramp(double value, double low, double high) {
        double t = (value-low)/(high-low);
        if (t < 0.0) t = 0.0;
        if (t > 1.0) t = 1.0;
        return t*t*(3.0-2.0*t);
    }
    PackedFloat64Array erode(const PackedFloat64Array &base, const PackedByteArray &fixed, const Dictionary &p) const {
        const int64_t n = int64_t(p["size"]), seed = int64_t(p["seed"]) & 0xffffffffLL, iterations = int64_t(p["iterations"]);
        const double cell = p["cell"], origin = p["origin"], detail = p["detail"], frequency = p["frequency"], warp = p["warp"];
        const double slope_ref = p["slope_ref"], k = p["k"], max_cut = p["max_cut"], deposit = p["deposit"];
        const double channel_area = p["channel_area"], jitter_amp = p["jitter"];
        const double deposit_slope = p["deposit_slope"], deposit_cap = p["deposit_cap"], edge_inner = p["edge_inner"], edge_outer = p["edge_outer"];
        const int64_t count = n*n;
        PackedFloat64Array out;
        if (n < 3 || base.size() != count || fixed.size() != count) return out;
        const double *b = base.ptr();
        const uint8_t *locked = fixed.ptr();
        std::vector<double> h(count), top(count), weight(count), before(count), eroded(count), area(count), sediment(count), distance(count), lowest(count), change(count), jitter(count*8);
        std::vector<int64_t> receiver(count), donors(count), donor(count*8), stack(count), todo(count);
        // 1. Ridged, domain-warped detail on the slopes; flats and the rim keep their shape.
        for (int64_t j = 0; j < n; ++j) for (int64_t i = 0; i < n; ++i) {
            const int64_t c = j*n+i;
            const double x = origin+double(i)*cell, z = origin+double(j)*cell;
            const double reach = std::max(std::fabs(x), std::fabs(z));
            double w = 1.0-ramp(reach, edge_inner, edge_outer);
            if (locked[c] != 0) w = 0.0;
            weight[c] = w;
            const int64_t l = i > 0 ? c-1 : c, r = i < n-1 ? c+1 : c, u = j > 0 ? c-n : c, d = j < n-1 ? c+n : c;
            const double sx = (b[r]-b[l])/(double(r-l)*cell), sz = (b[d]-b[u])/(double((d-u)/n)*cell);
            double s = std::sqrt(sx*sx+sz*sz)/slope_ref;
            if (s > 1.0) s = 1.0;
            const double fx = x*frequency, fz = z*frequency;
            const double qx = fx+warp*gradient(fx*0.5+3.1, fz*0.5+7.7, (seed+17) & 0xffffffffLL);
            const double qz = fz+warp*gradient(fx*0.5+11.3, fz*0.5+5.9, (seed+29) & 0xffffffffLL);
            h[c] = b[c]+detail*w*s*((ridged(qx, qz, seed)-0.575)*2.0);
            // Fixed random weights per direction let flow wander off the eight
            // grid axes and merge into branching gullies.
            for (int64_t m = 0; m < 8; ++m) jitter[c*8+m] = 1.0+(double(hash2(i*8+m, j, (seed+41) & 0xffffffffLL) & 65535)/65535.0-0.5)*jitter_amp;
            top[c] = h[c];
        }
        static const int64_t ox[8] = {-1, 0, 1, -1, 1, -1, 0, 1};
        static const int64_t oz[8] = {-1, -1, -1, 0, 0, 1, 1, 1};
        const double diagonal = cell*1.4142135623730951;
        // 2. Stream power, solved implicitly down the drainage tree, then the
        // carried sediment settles where the flow slackens.
        for (int64_t t = 0; t < iterations; ++t) {
            for (int64_t c = 0; c < count; ++c) {
                receiver[c] = c;
                distance[c] = cell;
                donors[c] = 0;
                lowest[c] = h[c];
                const int64_t i = c%n, j = c/n;
                if (locked[c] != 0 || i == 0 || j == 0 || i == n-1 || j == n-1) continue;
                double best = 0.0;
                lowest[c] = 1e30;
                for (int64_t m = 0; m < 8; ++m) {
                    const int64_t other = (j+oz[m])*n+i+ox[m];
                    const double d = (ox[m] != 0 && oz[m] != 0) ? diagonal : cell;
                    const double s = (h[c]-h[other])/d*jitter[c*8+m];
                    if (h[other] < lowest[c]) lowest[c] = h[other];
                    if (s > best) { best = s; receiver[c] = other; distance[c] = d; }
                }
            }
            for (int64_t c = 0; c < count; ++c) {
                const int64_t r = receiver[c];
                if (r != c) { donor[r*8+donors[r]] = c; donors[r] += 1; }
            }
            int64_t size = 0;
            for (int64_t c = 0; c < count; ++c) {
                if (receiver[c] != c) continue;
                int64_t pending = 0;
                todo[pending++] = c;
                while (pending > 0) {
                    const int64_t node = todo[--pending];
                    stack[size++] = node;
                    for (int64_t m = 0; m < donors[node]; ++m) todo[pending++] = donor[node*8+m];
                }
            }
            for (int64_t c = 0; c < count; ++c) { area[c] = 1.0; before[c] = h[c]; sediment[c] = 0.0; }
            for (int64_t s = count-1; s >= 0; --s) {
                const int64_t node = stack[s], r = receiver[node];
                if (r != node) area[r] += area[node];
            }
            for (int64_t s = 0; s < count; ++s) {
                const int64_t node = stack[s], r = receiver[node];
                if (r == node) continue;
                double drained = area[node]-channel_area;
                if (drained < 0.0) drained = 0.0;
                const double f = k*weight[node]*drained/distance[node];
                double next = (h[node]+f*h[r])/(1.0+f);
                const double floor = top[node]-max_cut;
                if (next < floor) next = floor;
                if (next < h[node]) h[node] = next;
            }
            for (int64_t c = 0; c < count; ++c) eroded[c] = before[c]-h[c];
            for (int64_t s = count-1; s >= 0; --s) {
                const int64_t node = stack[s], r = receiver[node];
                const double load = sediment[node]+eroded[node];
                double slack = 1.0;
                if (r != node) {
                    slack = 1.0-((h[node]-h[r])/distance[node])/deposit_slope;
                    if (slack < 0.0) slack = 0.0;
                }
                double keep = load*deposit*slack*weight[node];
                if (keep > deposit_cap) keep = deposit_cap;
                // Settle without burying the cells that drain here, and fill
                // a pit no higher than its lowest rim, so no mounds grow.
                double limit = r == node ? lowest[node] : 1e30;
                for (int64_t m = 0; m < donors[node]; ++m) limit = std::min(limit, h[donor[node*8+m]]);
                double room = limit-h[node];
                if (room < 0.0) room = 0.0;
                if (keep > room) keep = room;
                h[node] += keep;
                if (r != node) sediment[r] += load-keep;
            }
        }
        out.resize(count);
        double *delta = out.ptrw();
        // 3. A 1-2-1 blur widens single-cell channels to read on the ~0.7 m
        // mesh. The ridged detail stays sharp.
        for (int64_t c = 0; c < count; ++c) change[c] = h[c]-top[c];
        for (int64_t c = 0; c < count; ++c) {
            const int64_t i = c%n;
            delta[c] = (change[i > 0 ? c-1 : c]+change[c]*2.0+change[i < n-1 ? c+1 : c])*0.25;
        }
        for (int64_t c = 0; c < count; ++c) change[c] = delta[c];
        for (int64_t c = 0; c < count; ++c) {
            const int64_t j = c/n;
            delta[c] = (top[c]-b[c])+(change[j > 0 ? c-n : c]+change[c]*2.0+change[j < n-1 ? c+n : c])*0.25;
        }
        return out;
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
        // The plate's reach and the two grids' sizes (scripts/plate.gd,
        // NativeRecipeWater, NativeTerrainData); a caller that sends none gets
        // the 28 m plate's, which is what older callers meant.
        const double half = p.get("plate_half", 14.0);
        // The recipe's water field covers its own square (water_half), which
        // libraries built before the key took to be the plate's.
        const double water_half = p.get("water_half", half);
        const int water_cells = p.get("water_cells", 51), water_stride = water_cells+1;
        const double water_cell = 2.0*water_half/water_cells;
        const int meadow_cells = p.get("meadow_cells", 56);
        const float meadow_step = float(double(p.get("meadow_step", 0.5)));
        const bool wet = !water.is_empty();
        const PackedFloat32Array shore = wet ? PackedFloat32Array(water["shore"]) : PackedFloat32Array();
        const PackedFloat32Array depth = wet ? PackedFloat32Array(water["depth"]) : PackedFloat32Array();
        const PackedByteArray kind = wet ? PackedByteArray(water["kind"]) : PackedByteArray();
        auto grid = [&](const PackedFloat32Array &values, double x, double z) {
            const double fi = std::clamp((x+water_half)/water_cell, 0.0, double(water_cells));
            const double fj = std::clamp((z+water_half)/water_cell, 0.0, double(water_cells));
            const int i = std::min(water_cells-1, int(std::floor(fi))), j = std::min(water_cells-1, int(std::floor(fj)));
            const double u = fi-i, v = fj-j;
            const int k = j*water_stride+i;
            return values[k]*(1-u)*(1-v)+values[k+1]*u*(1-v)+values[k+water_stride]*(1-u)*v+values[k+water_stride+1]*u*v;
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
            const Vector2 meadow_grid = (Vector2(center.x, center.z)+Vector2(float(half), float(half)))/meadow_step;
            const int cell = std::clamp(int(meadow_grid.y), 0, meadow_cells-1)*meadow_cells+std::clamp(int(meadow_grid.x), 0, meadow_cells-1);
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
                    const int col = int(std::floor((x+water_half)/water_cell+0.5)), row = int(std::floor((z+water_half)/water_cell+0.5));
                    const bool running = col >= 0 && row >= 0 && col < water_stride && row < water_stride && kind[row*water_stride+col] == 2;
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
    if (level != MODULE_INITIALIZATION_LEVEL_SCENE) return;
    ClassDB::register_class<ZenScapeTerrainKernels>();
    ClassDB::register_class<ZenScapeWaterFlow>();
    ClassDB::register_class<ZenScapeIsleKernels>();
    ClassDB::register_class<ZenScapeLandField>();
    ClassDB::register_class<ZenScapeLandBand>();
    ClassDB::register_class<ZenScapeGrass>();
    ClassDB::register_class<ZenScapeTrees>();
    ClassDB::register_class<ZenScapeMotes>();
    ClassDB::register_class<ZenScapeRibbons>();
    ClassDB::register_class<ZenScapeBirds>();
    ClassDB::register_class<ZenScapePeak>();
}
extern "C" GDExtensionBool GDE_EXPORT zenscape_kernels_init(GDExtensionInterfaceGetProcAddress get_proc,
        GDExtensionClassLibraryPtr library, GDExtensionInitialization *initialization) {
    GDExtensionBinding::InitObject init(get_proc, library, initialization);
    init.register_initializer(initialize);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init.init();
}
