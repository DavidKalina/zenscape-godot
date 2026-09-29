// Live shallow water on a regular grid over the plate (docs/scenic/water-flow.md).
// Virtual pipes (O'Brien & Hodgins 1995, Mei et al. 2007): each cell keeps an
// outflow through a pipe to each of its four neighbours, accelerated by the
// difference in surface height (ground + water) and slowed by friction; the
// outflows are scaled so no cell gives more water than it holds, then every
// cell's depth moves by what flowed in less what flowed out. Ground heights are
// resampled from the terrain's irregular vertices at the start of every step,
// so any sculpt, undo or new world moves the water with no hook.
//
// scripts/water_flow_reference.gd is the GDScript mirror; keep the two in step.
// Pure numerical work: no Object, scene, renderer or physics calls.
#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/rect2.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <vector>

using namespace godot;

class ZenScapeWaterFlow : public RefCounted {
    GDCLASS(ZenScapeWaterFlow, RefCounted)
    // Cell kinds: outside the plate (a wall), water, and the plate's edge ring,
    // where water that arrives falls off the plate and is lost.
    enum { OUTSIDE = 0, WATER = 1, EDGE = 2 };
    int w = 0, h = 0;
    double cell = 0.25, ox = -14.0, oz = -14.0;
    std::vector<int32_t> face;   // 3 vertex ids per cell, -1 outside
    std::vector<float> weight;   // barycentric u, v per cell
    std::vector<uint8_t> kind;
    std::vector<float> ground, depth, next, vx, vz;
    std::vector<float> flux;     // 4 per cell: -x, +x, -z, +z outflow, m³/s
    std::vector<uint8_t> flowing;
    // Tunables (set_params); the defaults match scripts/water_flow.gd.
    double gravity = 9.81, friction = 0.6, drag = 0.06, evaporation = 0.00006, soak = 0.0035, soak_depth = 0.03, max_speed = 4.0;
    // Totals since configure, m³.
    double poured = 0.0, drained = 0.0, soaked = 0.0, removed = 0.0;
    int64_t last_usec = 0;
    int64_t steps = 0;

protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("configure", "width", "height", "cell", "origin", "faces", "weights"), &ZenScapeWaterFlow::configure);
        ClassDB::bind_method(D_METHOD("set_params", "params"), &ZenScapeWaterFlow::set_params);
        ClassDB::bind_method(D_METHOD("step", "heights", "sources", "ticks", "dt"), &ZenScapeWaterFlow::step);
        ClassDB::bind_method(D_METHOD("add_water", "center", "radius", "volume"), &ZenScapeWaterFlow::add_water);
        ClassDB::bind_method(D_METHOD("drain", "center", "radius"), &ZenScapeWaterFlow::drain);
        ClassDB::bind_method(D_METHOD("get_depth"), &ZenScapeWaterFlow::get_depth);
        ClassDB::bind_method(D_METHOD("set_depth", "values"), &ZenScapeWaterFlow::set_depth);
        ClassDB::bind_method(D_METHOD("get_ground"), &ZenScapeWaterFlow::get_ground);
        ClassDB::bind_method(D_METHOD("wet_cells", "min_depth"), &ZenScapeWaterFlow::wet_cells);
        ClassDB::bind_method(D_METHOD("get_velocity"), &ZenScapeWaterFlow::get_velocity);
        ClassDB::bind_method(D_METHOD("stats"), &ZenScapeWaterFlow::stats);
        ClassDB::bind_method(D_METHOD("surface", "params"), &ZenScapeWaterFlow::surface);
        ClassDB::bind_method(D_METHOD("pools", "min_depth", "max_speed", "min_cells"), &ZenScapeWaterFlow::pools);
        ClassDB::bind_method(D_METHOD("falls", "min_flux", "min_drop", "min_slope", "reach"), &ZenScapeWaterFlow::falls);
    }

    static int64_t now_usec() {
        return std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now().time_since_epoch()).count();
    }

    int index(double x, double z) const {
        const int i = int(std::floor((x-ox)/cell)), j = int(std::floor((z-oz)/cell));
        if (i < 0 || j < 0 || i >= w || j >= h) return -1;
        return j*w+i;
    }

    void resample(const PackedFloat32Array &heights) {
        const int64_t count = heights.size();
        const float *hp = heights.ptr();
        const int n = w*h;
        for (int c = 0; c < n; ++c) {
            if (kind[c] == OUTSIDE) continue;
            const int32_t a = face[c*3], b = face[c*3+1], e = face[c*3+2];
            if (a < 0 || a >= count || b >= count || e >= count) continue;
            const float u = weight[c*2], v = weight[c*2+1];
            ground[c] = u*hp[a]+v*hp[b]+(1.0f-u-v)*hp[e];
        }
    }

    // Adds `volume` m³ over a (1 - t²)² bump of `radius` around a point.
    double spread(double x, double z, double radius, double volume) {
        if (volume <= 0.0 || w == 0) return 0.0;
        radius = std::max(radius, cell*0.75);
        const int i0 = std::max(0, int(std::floor((x-radius-ox)/cell))), i1 = std::min(w-1, int(std::floor((x+radius-ox)/cell)));
        const int j0 = std::max(0, int(std::floor((z-radius-oz)/cell))), j1 = std::min(h-1, int(std::floor((z+radius-oz)/cell)));
        double total = 0.0;
        for (int pass = 0; pass < 2; ++pass) {
            const double scale = pass == 0 ? 0.0 : volume/(total*cell*cell);
            for (int j = j0; j <= j1; ++j) for (int i = i0; i <= i1; ++i) {
                const int c = j*w+i;
                if (kind[c] != WATER) continue;
                const double dx = ox+(i+0.5)*cell-x, dz = oz+(j+0.5)*cell-z;
                const double t = (dx*dx+dz*dz)/(radius*radius);
                if (t >= 1.0) continue;
                const double f = (1.0-t)*(1.0-t);
                if (pass == 0) total += f;
                else depth[c] += float(f*scale);
            }
            if (total <= 0.0) {
                // Smaller than a cell: all of it into the cell underneath.
                const int c = index(x, z);
                if (c < 0 || kind[c] != WATER) return 0.0;
                depth[c] += float(volume/(cell*cell));
                return volume;
            }
        }
        return volume;
    }

    void tick(double dt) {
        const int n = w*h;
        const double area = cell*cell;
        // 1. Outflows: accelerated by the surface drop to each neighbour through a
        // pipe as wide as the cell and as deep as the water it leaves, and slowed by
        // friction that grows as the water thins, solved implicitly.
        for (int j = 0; j < h; ++j) for (int i = 0; i < w; ++i) {
            const int c = j*w+i;
            float *f = &flux[c*4];
            if (kind[c] != WATER || depth[c] <= 0.0f) { f[0] = f[1] = f[2] = f[3] = 0.0f; continue; }
            const double d = depth[c];
            const double surface = ground[c]+d;
            const double damp = 1.0/(1.0+dt*(friction+drag/std::max(d, 0.004)));
            const int nb[4] = {i > 0 ? c-1 : -1, i < w-1 ? c+1 : -1, j > 0 ? c-w : -1, j < h-1 ? c+w : -1};
            double total = 0.0;
            for (int k = 0; k < 4; ++k) {
                const int m = nb[k];
                if (m < 0 || kind[m] == OUTSIDE) { f[k] = 0.0f; continue; }
                const double drop = surface-(ground[m]+depth[m]);
                double q = (f[k]+dt*gravity*d*drop)*damp;
                if (q < 0.0) q = 0.0;
                f[k] = float(q);
                total += q;
            }
            // Never give more than the cell holds.
            const double have = d*area;
            if (total*dt > have && total > 0.0) {
                const double k = have/(total*dt);
                for (int m = 0; m < 4; ++m) f[m] = float(f[m]*k);
            }
        }
        // 2. Depths and velocities.
        for (int j = 0; j < h; ++j) for (int i = 0; i < w; ++i) {
            const int c = j*w+i;
            if (kind[c] == OUTSIDE) { next[c] = 0.0f; continue; }
            const float *f = &flux[c*4];
            const double left = i > 0 ? flux[(c-1)*4+1] : 0.0, right = i < w-1 ? flux[(c+1)*4] : 0.0;
            const double up = j > 0 ? flux[(c-w)*4+3] : 0.0, down = j < h-1 ? flux[(c+w)*4+2] : 0.0;
            const double in = left+right+up+down, out = double(f[0])+f[1]+f[2]+f[3];
            double d = depth[c]+dt*(in-out)/area;
            if (d < 0.0) d = 0.0;
            const double mean = 0.5*(depth[c]+d);
            if (mean > 0.0005) {
                double u = 0.5*(left-f[0]+f[1]-right)/(cell*mean);
                double v = 0.5*(up-f[2]+f[3]-down)/(cell*mean);
                const double speed = std::sqrt(u*u+v*v);
                if (speed > max_speed) { u *= max_speed/speed; v *= max_speed/speed; }
                vx[c] = float(u); vz[c] = float(v);
            } else vx[c] = vz[c] = 0.0f;
            if (kind[c] == EDGE) {
                // Water that reaches the plate's edge falls off it.
                drained += d*area;
                d = 0.0;
            } else if (d > 0.0) {
                // Evaporation everywhere; thin water soaks into the ground too.
                const double loss = dt*(evaporation+soak*std::max(0.0, 1.0-d/soak_depth));
                const double lost = std::min(d, loss);
                soaked += lost*area;
                d -= lost;
                if (d < 1e-6) { soaked += d*area; d = 0.0; }
            }
            next[c] = float(d);
        }
        depth.swap(next);
    }

public:
    void configure(int width, int height, double cell_size, Vector2 origin, const PackedInt32Array &faces, const PackedFloat32Array &weights) {
        w = std::max(width, 0); h = std::max(height, 0);
        cell = cell_size; ox = origin.x; oz = origin.y;
        const int n = w*h;
        face.assign(n*3, -1); weight.assign(n*2, 0.0f); kind.assign(n, OUTSIDE);
        ground.assign(n, 0.0f); depth.assign(n, 0.0f); next.assign(n, 0.0f);
        vx.assign(n, 0.0f); vz.assign(n, 0.0f); flux.assign(n*4, 0.0f); flowing.assign(n, 0);
        poured = drained = soaked = removed = 0.0;
        steps = 0;
        if (faces.size() != n*3 || weights.size() != n*2) { w = h = 0; return; }
        for (int c = 0; c < n; ++c) {
            face[c*3] = faces[c*3]; face[c*3+1] = faces[c*3+1]; face[c*3+2] = faces[c*3+2];
            weight[c*2] = weights[c*2]; weight[c*2+1] = weights[c*2+1];
            kind[c] = face[c*3] >= 0 ? WATER : OUTSIDE;
        }
        // The edge ring: plate cells beside the grid's border or beside outside.
        for (int j = 0; j < h; ++j) for (int i = 0; i < w; ++i) {
            const int c = j*w+i;
            if (kind[c] != WATER) continue;
            if (i == 0 || j == 0 || i == w-1 || j == h-1 || kind[c-1] == OUTSIDE || kind[c+1] == OUTSIDE || kind[c-w] == OUTSIDE || kind[c+w] == OUTSIDE) kind[c] = EDGE;
        }
    }

    void set_params(const Dictionary &p) {
        gravity = p.get("gravity", gravity); friction = p.get("friction", friction); drag = p.get("drag", drag);
        evaporation = p.get("evaporation", evaporation); soak = p.get("soak", soak); soak_depth = p.get("soak_depth", soak_depth);
        max_speed = p.get("max_speed", max_speed);
    }

    // `sources`: x, z, radius, rate (m³/s) per source. Returns the step's usec.
    int64_t step(const PackedFloat32Array &heights, const PackedFloat32Array &sources, int ticks, double dt) {
        if (w == 0) return 0;
        const int64_t began = now_usec();
        resample(heights);
        const int64_t count = sources.size()/4;
        for (int t = 0; t < ticks; ++t) {
            for (int64_t s = 0; s < count; ++s) poured += spread(sources[s*4], sources[s*4+1], sources[s*4+2], double(sources[s*4+3])*dt);
            tick(dt);
            ++steps;
        }
        last_usec = now_usec()-began;
        return last_usec;
    }

    double add_water(Vector2 center, double radius, double volume) {
        const double added = spread(center.x, center.y, radius, volume);
        poured += added;
        return added;
    }

    double drain(Vector2 center, double radius) {
        double taken = 0.0;
        for (int j = 0; j < h; ++j) for (int i = 0; i < w; ++i) {
            const int c = j*w+i;
            const double dx = ox+(i+0.5)*cell-center.x, dz = oz+(j+0.5)*cell-center.y;
            if (dx*dx+dz*dz >= radius*radius) continue;
            taken += depth[c]*cell*cell;
            depth[c] = 0.0f;
            flux[c*4] = flux[c*4+1] = flux[c*4+2] = flux[c*4+3] = 0.0f;
        }
        removed += taken;
        return taken;
    }

    PackedFloat32Array get_depth() const {
        PackedFloat32Array out;
        out.resize(depth.size());
        std::copy(depth.begin(), depth.end(), out.ptrw());
        return out;
    }

    void set_depth(const PackedFloat32Array &values) {
        if (values.size() != int64_t(depth.size())) return;
        const float *p = values.ptr();
        for (size_t c = 0; c < depth.size(); ++c) depth[c] = kind[c] == WATER ? std::max(p[c], 0.0f) : 0.0f;
        std::fill(flux.begin(), flux.end(), 0.0f);
        std::fill(vx.begin(), vx.end(), 0.0f);
        std::fill(vz.begin(), vz.end(), 0.0f);
    }

    PackedFloat32Array get_ground() const {
        PackedFloat32Array out;
        out.resize(ground.size());
        std::copy(ground.begin(), ground.end(), out.ptrw());
        return out;
    }

    // 1 per cell standing `min_depth` or deeper, else 0.
    PackedByteArray wet_cells(double min_depth) const {
        PackedByteArray out;
        out.resize(depth.size());
        uint8_t *p = out.ptrw();
        for (size_t c = 0; c < depth.size(); ++c) p[c] = depth[c] >= min_depth ? 1 : 0;
        return out;
    }

    PackedVector2Array get_velocity() const {
        PackedVector2Array out;
        out.resize(vx.size());
        Vector2 *p = out.ptrw();
        for (size_t c = 0; c < vx.size(); ++c) p[c] = Vector2(vx[c], vz[c]);
        return out;
    }

    Dictionary stats() const {
        double volume = 0.0;
        int64_t wet = 0;
        for (size_t c = 0; c < depth.size(); ++c) {
            volume += depth[c];
            if (depth[c] > 0.01f) ++wet;
        }
        Dictionary out;
        out["volume"] = volume*cell*cell;
        out["poured"] = poured;
        out["drained"] = drained;
        out["soaked"] = soaked;
        out["removed"] = removed;
        out["wet_cells"] = wet;
        out["usec"] = last_usec;
        out["steps"] = steps;
        out["native"] = true;
        return out;
    }

    // The water surface as two meshes' arrays: "still" (ponds, the lake shader)
    // and "flow" (moving water, the stream shader). One vertex per cell centre;
    // a quad is drawn when any corner is wet. A dry corner of a drawn quad takes
    // the mean surface of its wet neighbours, or sits just under its own ground
    // when that is lower, so the sheet meets the bank and the terrain hides the
    // edge. Params: wet, lift, flow_on, flow_off, foam_from, foam_to, shallow,
    // deep, foam (linear colours), depth_scale.
    Dictionary surface(const Dictionary &p) {
        const double wet = p.get("wet", 0.012), lift = p.get("lift", 0.01);
        const double flow_on = p.get("flow_on", 0.22), flow_off = p.get("flow_off", 0.12);
        const double foam_from = p.get("foam_from", 0.8), foam_to = p.get("foam_to", 2.2), depth_scale = p.get("depth_scale", 0.45);
        const Color shallow = p.get("shallow", Color(0.2, 0.42, 0.33)), deep = p.get("deep", Color(0.02, 0.1, 0.11)), foam = p.get("foam", Color(0.65, 0.8, 0.79));
        const int n = w*h;
        std::vector<float> top(n, 0.0f);
        std::vector<uint8_t> state(n, 0); // 0 none, 1 wet, 2 shore
        for (int c = 0; c < n; ++c) if (kind[c] != OUTSIDE && depth[c] > wet) { state[c] = 1; top[c] = ground[c]+depth[c]; }
        for (int j = 0; j < h; ++j) for (int i = 0; i < w; ++i) {
            const int c = j*w+i;
            if (state[c] != 0 || kind[c] == OUTSIDE) continue;
            double sum = 0.0; int found = 0;
            for (int dj = -1; dj <= 1; ++dj) for (int di = -1; di <= 1; ++di) {
                const int a = i+di, b = j+dj;
                if (a < 0 || b < 0 || a >= w || b >= h) continue;
                const int m = b*w+a;
                if (state[m] == 1) { sum += top[m]; ++found; }
            }
            if (found == 0) continue;
            state[c] = 2;
            top[c] = float(std::min(sum/found, double(ground[c])-0.02));
        }
        // Moving or still, with a little hysteresis so the split does not flicker.
        for (int c = 0; c < n; ++c) {
            if (state[c] != 1) { flowing[c] = 0; continue; }
            const double speed = std::sqrt(double(vx[c])*vx[c]+double(vz[c])*vz[c]);
            if (speed > flow_on) flowing[c] = 1;
            else if (speed < flow_off) flowing[c] = 0;
        }
        Dictionary out;
        for (int set = 0; set < 2; ++set) {
            std::vector<int32_t> slot(n, -1);
            PackedVector3Array vertices;
            PackedColorArray colors;
            PackedVector2Array uv, uv2;
            PackedFloat32Array custom0, custom1;
            PackedInt32Array indices;
            auto vertex = [&](int c) -> int32_t {
                if (slot[c] >= 0) return slot[c];
                const int i = c%w, j = c/w;
                const double x = ox+(i+0.5)*cell, z = oz+(j+0.5)*cell, y = top[c]+lift;
                const double d = std::max(0.0, double(top[c])-double(ground[c]));
                slot[c] = int32_t(vertices.size());
                vertices.push_back(Vector3(float(x), float(y), float(z)));
                Color color = shallow.lerp(deep, float(1.0-std::exp(-d/depth_scale)));
                uv2.push_back(Vector2(float(d), 0.0f));
                if (set == 1) {
                    // Along and across the flow, so the stream shader's streaks run
                    // downstream; foam where it is fast.
                    double u = vx[c], v = vz[c];
                    double speed = std::sqrt(u*u+v*v);
                    if (state[c] != 1 || speed < 1e-4) {
                        // A bank corner borrows its wet neighbours' heading.
                        u = v = 0.0;
                        for (int dj = -1; dj <= 1; ++dj) for (int di = -1; di <= 1; ++di) {
                            const int a = i+di, b = j+dj;
                            if (a < 0 || b < 0 || a >= w || b >= h) continue;
                            const int m = b*w+a;
                            if (state[m] == 1) { u += vx[m]; v += vz[m]; }
                        }
                        speed = std::sqrt(u*u+v*v);
                    }
                    const double ax = speed > 1e-4 ? u/speed : 1.0, az = speed > 1e-4 ? v/speed : 0.0;
                    uv.push_back(Vector2(float(x*ax+z*az), float(-x*az+z*ax)));
                    double t = (speed-foam_from)/(foam_to-foam_from);
                    t = std::min(1.0, std::max(0.0, t));
                    color = color.lerp(foam, float(t*t*(3.0-2.0*t)*0.55));
                    custom0.push_back(float(x)); custom0.push_back(float(y)); custom0.push_back(float(z)); custom0.push_back(-1.0f);
                    for (int k = 0; k < 4; ++k) custom1.push_back(0.0f);
                } else {
                    uv.push_back(Vector2(0.0f, 0.0f));
                    // Shore fetch in eight directions (NativeTerrainData.pond_fetch),
                    // in half-metre steps up to 9 m, for the lake chop.
                    static const int di8[8] = {1, 1, 0, -1, -1, -1, 0, 1};
                    static const int dj8[8] = {0, 1, 1, 1, 0, -1, -1, -1};
                    const int stride = std::max(1, int(std::lround(0.5/cell)));
                    float fetch[8];
                    for (int k = 0; k < 8; ++k) {
                        const double stepped = (di8[k] != 0 && dj8[k] != 0 ? 1.41421356 : 1.0)*stride*cell;
                        double run = 0.0;
                        for (int s = 1; s <= 18; ++s) {
                            const int a = i+di8[k]*stride*s, b = j+dj8[k]*stride*s;
                            if (a < 0 || b < 0 || a >= w || b >= h) break;
                            if (state[b*w+a] != 1) break;
                            run = s*stepped;
                            if (run >= 9.0) break;
                        }
                        fetch[k] = float(run);
                    }
                    for (int k = 0; k < 4; ++k) custom0.push_back(fetch[k]);
                    for (int k = 4; k < 8; ++k) custom1.push_back(fetch[k]);
                }
                colors.push_back(color);
                return slot[c];
            };
            for (int j = 0; j < h-1; ++j) for (int i = 0; i < w-1; ++i) {
                const int a = j*w+i, b = a+1, c = a+w, d = c+1;
                if (!state[a] || !state[b] || !state[c] || !state[d]) continue;
                if (state[a] != 1 && state[b] != 1 && state[c] != 1 && state[d] != 1) continue;
                const bool moving = flowing[a] || flowing[b] || flowing[c] || flowing[d];
                if (moving != (set == 1)) continue;
                // Split along the lower diagonal so a spill reads as a slope, not a fold.
                const bool split = std::fabs(top[a]-top[d]) <= std::fabs(top[b]-top[c]);
                const int32_t va = vertex(a), vb = vertex(b), vc = vertex(c), vd = vertex(d);
                if (split) {
                    indices.push_back(va); indices.push_back(vb); indices.push_back(vd);
                    indices.push_back(va); indices.push_back(vd); indices.push_back(vc);
                } else {
                    indices.push_back(va); indices.push_back(vb); indices.push_back(vc);
                    indices.push_back(vb); indices.push_back(vd); indices.push_back(vc);
                }
            }
            Dictionary arrays;
            arrays["vertices"] = vertices;
            arrays["colors"] = colors;
            arrays["uv"] = uv;
            arrays["uv2"] = uv2;
            arrays["custom0"] = custom0;
            arrays["custom1"] = custom1;
            arrays["indices"] = indices;
            out[set == 0 ? "still" : "flow"] = arrays;
        }
        return out;
    }

    // Standing water: 4-connected groups of cells deeper than `min_depth` and
    // slower than `max_speed`, of at least `min_cells`. Each is {"x", "z" (its
    // deepest cell), "cells", "area", "level", "depth", "rect"}.
    Array pools(double min_depth, double max_speed_still, int min_cells) const {
        Array out;
        const int n = w*h;
        std::vector<int32_t> seen(n, 0);
        std::vector<int32_t> todo;
        for (int s = 0; s < n; ++s) {
            if (seen[s] || kind[s] == OUTSIDE || depth[s] <= min_depth) continue;
            if (double(vx[s])*vx[s]+double(vz[s])*vz[s] > max_speed_still*max_speed_still) continue;
            todo.clear(); todo.push_back(s); seen[s] = 1;
            int count = 0, deepest = s, i0 = w, j0 = h, i1 = -1, j1 = -1;
            double level = 0.0;
            while (!todo.empty()) {
                const int c = todo.back(); todo.pop_back();
                ++count;
                level += ground[c]+depth[c];
                if (depth[c] > depth[deepest]) deepest = c;
                const int i = c%w, j = c/w;
                i0 = std::min(i0, i); i1 = std::max(i1, i); j0 = std::min(j0, j); j1 = std::max(j1, j);
                const int nb[4] = {i > 0 ? c-1 : -1, i < w-1 ? c+1 : -1, j > 0 ? c-w : -1, j < h-1 ? c+w : -1};
                for (int m : nb) {
                    if (m < 0 || seen[m] || kind[m] == OUTSIDE || depth[m] <= min_depth) continue;
                    if (double(vx[m])*vx[m]+double(vz[m])*vz[m] > max_speed_still*max_speed_still) continue;
                    seen[m] = 1;
                    todo.push_back(m);
                }
            }
            if (count < min_cells) continue;
            Dictionary pool;
            pool["x"] = ox+(deepest%w+0.5)*cell;
            pool["z"] = oz+(deepest/w+0.5)*cell;
            pool["cells"] = count;
            pool["area"] = count*cell*cell;
            pool["level"] = level/count;
            pool["depth"] = depth[deepest];
            pool["rect"] = Rect2(float(ox+i0*cell), float(oz+j0*cell), float((i1-i0+1)*cell), float((j1-j0+1)*cell));
            out.push_back(pool);
        }
        return out;
    }

    // Where moving water drops steeply: cells carrying at least `min_flux` m³/s
    // whose surface falls `min_drop` m or more, at `min_slope` or steeper, within
    // `reach` m downstream along the flow. Flat: x0, y0, z0, x1, y1, z1, flux per
    // fall, strongest first, with falls closer than `reach` merged.
    PackedFloat32Array falls(double min_flux, double min_drop, double min_slope, double reach) const {
        struct Fall { double x0, y0, z0, x1, y1, z1, q; };
        std::vector<Fall> found;
        const int n = w*h;
        for (int c = 0; c < n; ++c) {
            if (kind[c] != WATER || depth[c] < 0.004f) continue;
            const double q = double(flux[c*4])+flux[c*4+1]+flux[c*4+2]+flux[c*4+3];
            if (q < min_flux) continue;
            const double speed = std::sqrt(double(vx[c])*vx[c]+double(vz[c])*vz[c]);
            if (speed < 0.05) continue;
            const double ax = vx[c]/speed, az = vz[c]/speed;
            const int i = c%w, j = c/w;
            const double x = ox+(i+0.5)*cell, z = oz+(j+0.5)*cell, y = ground[c]+depth[c];
            double best = 0.0; Fall fall{};
            for (double run = cell; run <= reach+1e-6; run += cell) {
                const int m = index(x+ax*run, z+az*run);
                if (m < 0 || kind[m] == OUTSIDE) break;
                const double drop = y-(ground[m]+depth[m]);
                if (drop >= min_drop && drop >= run*min_slope && drop > best) {
                    best = drop;
                    fall = {x, y, z, x+ax*run, ground[m]+depth[m], z+az*run, q};
                }
            }
            if (best > 0.0) found.push_back(fall);
        }
        std::sort(found.begin(), found.end(), [](const Fall &a, const Fall &b) { return a.q > b.q; });
        std::vector<Fall> kept;
        for (const Fall &f : found) {
            bool near = false;
            for (const Fall &k : kept) {
                const double dx = f.x0-k.x0, dz = f.z0-k.z0;
                if (dx*dx+dz*dz < reach*reach) { near = true; break; }
            }
            if (!near) kept.push_back(f);
            if (kept.size() >= 8) break;
        }
        PackedFloat32Array out;
        for (const Fall &f : kept) {
            out.push_back(float(f.x0)); out.push_back(float(f.y0)); out.push_back(float(f.z0));
            out.push_back(float(f.x1)); out.push_back(float(f.y1)); out.push_back(float(f.z1));
            out.push_back(float(f.q));
        }
        return out;
    }
};
