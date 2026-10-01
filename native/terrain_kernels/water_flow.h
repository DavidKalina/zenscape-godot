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
#include <godot_cpp/variant/packed_vector4_array.hpp>
#include <godot_cpp/variant/rect2.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector4.hpp>
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
    // Seconds each cell's ground has stood wet, up to `saturate`: wet ground
    // soaks less and less, and saturated ground soaks nothing, so a stream
    // that keeps running carries its water on instead of losing it to the
    // ground it already wet. Dry ground dries back at `dry_rate` of real time.
    std::vector<float> wet;
    // The edge ring's outflow (docs/scenic/water-flow.md "Edge falls"): each
    // edge cell's side (0 -x, 1 +x, 2 -z, 3 +z), the plate cell inward of it,
    // the volume drained into it over the current step, and the smoothed rate
    // (m³/s) and brink depth (m) of the water leaving over it.
    std::vector<int32_t> edge_cells, edge_inner;
    std::vector<uint8_t> edge_side;
    std::vector<int8_t> side_of;   // per cell: its edge side, or -1
    std::vector<double> edge_acc;
    std::vector<float> edge_rate, edge_brink;
    // Seconds: the time constant the edge outflow is smoothed with.
    double edge_smooth = 0.5;
    // Tunables (set_params); the defaults match scripts/water_flow.gd.
    double gravity = 9.81, friction = 0.6, drag = 0.06, evaporation = 0.00006, soak = 0.0035, soak_depth = 0.03, max_speed = 4.0;
    double saturate = 0.0, dry_rate = 0.1;
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
        ClassDB::bind_method(D_METHOD("cascades", "params"), &ZenScapeWaterFlow::cascades);
        ClassDB::bind_method(D_METHOD("edge_outflow"), &ZenScapeWaterFlow::edge_outflow);
        ClassDB::bind_method(D_METHOD("spills", "params"), &ZenScapeWaterFlow::spills);
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
                // Water that reaches the plate's edge falls off it; the edge
                // falls read how much, cell by cell.
                drained += d*area;
                edge_acc[c] += d*area;
                d = 0.0;
            } else if (d > 0.0) {
                // Evaporation everywhere; thin water soaks into ground not yet
                // saturated too.
                const double thirst = saturate > 0.0 ? std::max(0.0, 1.0-wet[c]/saturate) : 1.0;
                const double loss = dt*(evaporation+soak*thirst*std::max(0.0, 1.0-d/soak_depth));
                const double lost = std::min(d, loss);
                soaked += lost*area;
                d -= lost;
                if (d < 1e-6) { soaked += d*area; d = 0.0; }
            }
            next[c] = float(d);
            if (saturate > 0.0) wet[c] = d > 0.002 ? float(std::min(saturate, double(wet[c])+dt)) : float(std::max(0.0, double(wet[c])-dt*dry_rate));
        }
        depth.swap(next);
    }

    // The edge's outflow over the last `seconds`: each edge cell's rate eased
    // with `edge_smooth`, the brink depth that rate makes (critical depth,
    // (q²/g)^⅓ for q per metre of lip), and the inward cell's velocity (an
    // edge cell's own is meaningless: it never holds water).
    void settle_edge(double seconds) {
        if (seconds <= 0.0) return;
        const double k = 1.0-std::exp(-seconds/edge_smooth);
        for (size_t e = 0; e < edge_cells.size(); ++e) {
            const int c = edge_cells[e], m = edge_inner[e];
            const double rate = edge_acc[c]/seconds;
            edge_acc[c] = 0.0;
            edge_rate[c] = float(edge_rate[c]+(rate-edge_rate[c])*k);
            if (edge_rate[c] < 1e-7f) edge_rate[c] = 0.0f;
            const double q = edge_rate[c]/cell;
            edge_brink[c] = float(std::cbrt(q*q/gravity));
            vx[c] = vx[m]; vz[c] = vz[m];
        }
    }

public:
    void configure(int width, int height, double cell_size, Vector2 origin, const PackedInt32Array &faces, const PackedFloat32Array &weights) {
        w = std::max(width, 0); h = std::max(height, 0);
        cell = cell_size; ox = origin.x; oz = origin.y;
        const int n = w*h;
        face.assign(n*3, -1); weight.assign(n*2, 0.0f); kind.assign(n, OUTSIDE);
        ground.assign(n, 0.0f); depth.assign(n, 0.0f); next.assign(n, 0.0f);
        vx.assign(n, 0.0f); vz.assign(n, 0.0f); flux.assign(n*4, 0.0f); flowing.assign(n, 0); steep.assign(n, 0); wet.assign(n, 0.0f);
        edge_acc.assign(n, 0.0); edge_rate.assign(n, 0.0f); edge_brink.assign(n, 0.0f);
        edge_cells.clear(); edge_inner.clear(); edge_side.clear(); side_of.assign(n, -1);
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
        // Each edge cell's side and the cell inward of it. Corners go to the
        // x sides; a cell beside outside faces the outside neighbour.
        for (int j = 0; j < h; ++j) for (int i = 0; i < w; ++i) {
            const int c = j*w+i;
            if (kind[c] != EDGE) continue;
            int side;
            if (i == 0) side = 0;
            else if (i == w-1) side = 1;
            else if (j == 0) side = 2;
            else if (j == h-1) side = 3;
            else side = kind[c-1] == OUTSIDE ? 0 : kind[c+1] == OUTSIDE ? 1 : kind[c-w] == OUTSIDE ? 2 : 3;
            static const int step_i[4] = {1, -1, 0, 0}, step_j[4] = {0, 0, 1, -1};
            const int a = std::min(std::max(i+step_i[side], 0), w-1), b = std::min(std::max(j+step_j[side], 0), h-1);
            edge_cells.push_back(c);
            edge_inner.push_back(b*w+a);
            edge_side.push_back(uint8_t(side));
            side_of[c] = int8_t(side);
        }
    }

    void set_params(const Dictionary &p) {
        gravity = p.get("gravity", gravity); friction = p.get("friction", friction); drag = p.get("drag", drag);
        evaporation = p.get("evaporation", evaporation); soak = p.get("soak", soak); soak_depth = p.get("soak_depth", soak_depth);
        max_speed = p.get("max_speed", max_speed);
        saturate = std::max(0.0, double(p.get("saturate", saturate))); dry_rate = std::max(0.0, double(p.get("dry_rate", dry_rate)));
        edge_smooth = std::max(0.01, double(p.get("edge_smooth", edge_smooth)));
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
        settle_edge(ticks*dt);
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
        std::fill(edge_rate.begin(), edge_rate.end(), 0.0f);
        std::fill(edge_brink.begin(), edge_brink.end(), 0.0f);
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
        double volume = 0.0, edge_flux = 0.0;
        int64_t wet = 0;
        for (size_t c = 0; c < depth.size(); ++c) {
            volume += depth[c];
            if (depth[c] > 0.01f) ++wet;
        }
        for (int c : edge_cells) edge_flux += edge_rate[c];
        Dictionary out;
        out["edge_flux"] = edge_flux;
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
    // deep, foam (linear colours), depth_scale, under. Still water's UV.x is
    // its distance from dry ground, m (0 on the bank). With `under`, "still"
    // holds every drawn quad, the calm ones first ("calm" indices of them), so
    // moving water lies over still water; moving vertices carry in CUSTOM1.x
    // how fast they run between flow_off (0) and flow_on (1), to fade by.
    Dictionary surface(const Dictionary &p) {
        const double wet = p.get("wet", 0.012), lift = p.get("lift", 0.01);
        const double flow_on = p.get("flow_on", 0.22), flow_off = p.get("flow_off", 0.12);
        const double foam_from = p.get("foam_from", 0.8), foam_to = p.get("foam_to", 2.2), depth_scale = p.get("depth_scale", 0.45);
        const Color shallow = p.get("shallow", Color(0.2, 0.42, 0.33)), deep = p.get("deep", Color(0.02, 0.1, 0.11)), foam = p.get("foam", Color(0.65, 0.8, 0.79));
        const bool under = p.get("under", false);
        const double edge_on = p.get("edge_on", 0.0005);
        const int n = w*h;
        std::vector<float> top(n, 0.0f);
        std::vector<uint8_t> state(n, 0); // 0 none, 1 wet, 2 shore
        for (int c = 0; c < n; ++c) if (kind[c] != OUTSIDE && depth[c] > wet) { state[c] = 1; top[c] = ground[c]+depth[c]; }
        // An edge cell water leaves over is drawn at its brink depth, and its
        // vertex stands on the plate's rim, so the sheet runs to the lip.
        for (int c : edge_cells) if (edge_rate[c] > edge_on) { state[c] = 1; top[c] = float(ground[c]+std::max(double(edge_brink[c]), wet*1.5)); }
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
        // How far each wet cell lies from dry ground (a cell not drawn wet), in
        // metres, by a chamfer distance: bank corners 0. Still water carries it
        // in UV.x, so the shore foam follows the bank rather than the depth.
        std::vector<float> shore(n, 0.0f);
        const float diagonal = float(cell*1.41421356);
        for (int c = 0; c < n; ++c) if (state[c] == 1) shore[c] = 1e6f;
        for (int pass = 0; pass < 2; ++pass) {
            const int from = pass == 0 ? 0 : n-1, to = pass == 0 ? n : -1, step = pass == 0 ? 1 : -1;
            for (int c = from; c != to; c += step) {
                if (state[c] != 1) continue;
                const int i = c%w, j = c/w;
                float best = shore[c];
                for (int dj = -1; dj <= 1; ++dj) for (int di = -1; di <= 1; ++di) {
                    if (di == 0 && dj == 0) continue;
                    const int a = i+di, b = j+dj;
                    const float d = (di != 0 && dj != 0) ? diagonal : float(cell);
                    if (a < 0 || b < 0 || a >= w || b >= h) { best = std::min(best, d); continue; }
                    const int m = b*w+a;
                    best = std::min(best, (state[m] == 1 ? shore[m] : 0.0f)+d);
                }
                shore[c] = best;
            }
        }
        // Moving or still, with a little hysteresis so the split does not flicker.
        for (int c = 0; c < n; ++c) {
            if (state[c] != 1) { flowing[c] = 0; continue; }
            const double speed = std::sqrt(double(vx[c])*vx[c]+double(vz[c])*vz[c]);
            if (speed > flow_on) flowing[c] = 1;
            else if (speed < flow_off) flowing[c] = 0;
        }
        // How fast each wet cell runs, 0 at flow_off to 1 at flow_on; a bank
        // corner takes its fastest wet neighbour's.
        std::vector<float> fade(n, 0.0f);
        for (int c = 0; c < n; ++c) {
            if (state[c] != 1) continue;
            const double speed = std::sqrt(double(vx[c])*vx[c]+double(vz[c])*vz[c]);
            fade[c] = float(std::min(1.0, std::max(0.0, (speed-flow_off)/std::max(flow_on-flow_off, 1e-6))));
        }
        for (int j = 0; j < h; ++j) for (int i = 0; i < w; ++i) {
            const int c = j*w+i;
            if (state[c] != 2) continue;
            float most = 0.0f;
            for (int dj = -1; dj <= 1; ++dj) for (int di = -1; di <= 1; ++di) {
                const int a = i+di, b = j+dj;
                if (a < 0 || b < 0 || a >= w || b >= h) continue;
                const int m = b*w+a;
                if (state[m] == 1) most = std::max(most, fade[m]);
            }
            fade[c] = most;
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
                double x = ox+(i+0.5)*cell, z = oz+(j+0.5)*cell;
                const double y = top[c]+lift;
                if (state[c] == 1 && side_of[c] >= 0) {
                    static const double out_x[4] = {-0.5, 0.5, 0.0, 0.0}, out_z[4] = {0.0, 0.0, -0.5, 0.5};
                    x += out_x[side_of[c]]*cell; z += out_z[side_of[c]]*cell;
                }
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
                    // The flow's velocity (m/s), the mean of the wet cells
                    // round it, for the stream shader's flow map (live_flow_map).
                    double mu = 0.0, mv = 0.0;
                    int moving = 0;
                    for (int dj = -1; dj <= 1; ++dj) for (int di = -1; di <= 1; ++di) {
                        const int a = i+di, b = j+dj;
                        if (a < 0 || b < 0 || a >= w || b >= h) continue;
                        const int m = b*w+a;
                        if (state[m] == 1) { mu += vx[m]; mv += vz[m]; ++moving; }
                    }
                    if (moving > 0) { mu /= moving; mv /= moving; }
                    custom1.push_back(fade[c]);
                    custom1.push_back(float(mu)); custom1.push_back(float(mv)); custom1.push_back(0.0f);
                } else {
                    uv.push_back(Vector2(shore[c], 0.0f));
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
            int calm = 0;
            // Still water with `under` takes the calm quads, then the moving ones.
            for (int pass = 0; pass < (set == 0 && under ? 2 : 1); ++pass) {
                if (pass == 1) calm = int(indices.size());
                for (int j = 0; j < h-1; ++j) for (int i = 0; i < w-1; ++i) {
                    const int a = j*w+i, b = a+1, c = a+w, d = c+1;
                    if (!state[a] || !state[b] || !state[c] || !state[d]) continue;
                    if (state[a] != 1 && state[b] != 1 && state[c] != 1 && state[d] != 1) continue;
                    const bool moving = flowing[a] || flowing[b] || flowing[c] || flowing[d];
                    if (moving != (set == 1 || pass == 1)) continue;
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
            }
            if (set == 0 && !under) calm = int(indices.size());
            Dictionary arrays;
            arrays["vertices"] = vertices;
            arrays["colors"] = colors;
            arrays["uv"] = uv;
            arrays["uv2"] = uv2;
            arrays["custom0"] = custom0;
            arrays["custom1"] = custom1;
            arrays["indices"] = indices;
            arrays["calm"] = calm;
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

    // Waterfalls for the view (docs/scenic/water-flow.md "Waterfalls"): where
    // fast water crosses a big drop over a short run. A wet cell (deeper than
    // `wet`) running faster than `min_speed` is steep when its surface falls
    // `slope_on` m per metre or more over `run` m down its flow, and stays
    // steep until that is under `slope_off` (per-cell hysteresis, `steep`).
    // Steep cells group 8-connected. A group of `min_cells` or more is a fall
    // when its lip stands `min_drop` m or more over its plunge and it carries
    // `min_flux` m³/s: the larger of what flows into it from outside and what
    // flows out. Each fall, the largest flux first (at most `max`) is
    // {"flux", "drop", "cells", "lip" (Vector3: the depth-weighted mean of the
    // cells within `lip_band` of the top), "lip_dir" (Vector2, the flow there),
    // "lip_half" (half the lip's width across lip_dir), "plunge" (Vector3,
    // flux-weighted, where the water leaving it lands), "plunge_depth",
    // "course" (PackedVector4Array: x, y, z and half width, from lip to
    // plunge, at stations `band` m of drop apart)}.
    std::vector<uint8_t> steep;
    Array cascades(const Dictionary &p) {
        const double wet = p.get("wet", 0.01), min_speed = p.get("min_speed", 0.3);
        const double slope_on = p.get("slope_on", 1.0), slope_off = p.get("slope_off", 0.7), run = p.get("run", 0.5);
        const double min_drop = p.get("min_drop", 0.6), min_flux = p.get("min_flux", 0.004);
        const double lip_band = p.get("lip_band", 0.3), band = std::max(0.05, double(p.get("band", 0.3)));
        const int min_cells = p.get("min_cells", 3), most = p.get("max", 6);
        const int n = w*h;
        Array out;
        if (n == 0) return out;
        if (int(steep.size()) != n) steep.assign(n, 0);
        std::vector<float> top(n);
        for (int c = 0; c < n; ++c) top[c] = ground[c]+depth[c];
        // 1. Steep cells, with hysteresis.
        for (int c = 0; c < n; ++c) {
            uint8_t s = 0;
            if (kind[c] == WATER && depth[c] > wet) {
                const double speed = std::sqrt(double(vx[c])*vx[c]+double(vz[c])*vz[c]);
                if (speed > min_speed) {
                    const double x = ox+(c%w+0.5)*cell, z = oz+(c/w+0.5)*cell;
                    const int m = index(x+vx[c]/speed*run, z+vz[c]/speed*run);
                    if (m >= 0 && m != c && kind[m] != OUTSIDE) {
                        const double slope = (double(top[c])-top[m])/run;
                        s = slope >= (steep[c] ? slope_off : slope_on) ? 1 : 0;
                    }
                }
            }
            steep[c] = s;
        }
        // 2. Groups.
        struct Found { double flux; Dictionary fall; };
        std::vector<Found> found;
        std::vector<int32_t> group(n, -1);
        std::vector<int32_t> cells, todo;
        int serial = 0;
        for (int s = 0; s < n; ++s) {
            if (!steep[s] || group[s] >= 0) continue;
            cells.clear(); todo.clear();
            todo.push_back(s); group[s] = serial;
            while (!todo.empty()) {
                const int c = todo.back(); todo.pop_back();
                cells.push_back(c);
                const int i = c%w, j = c/w;
                for (int dj = -1; dj <= 1; ++dj) for (int di = -1; di <= 1; ++di) {
                    const int a = i+di, b = j+dj;
                    if (a < 0 || b < 0 || a >= w || b >= h) continue;
                    const int m = b*w+a;
                    if (steep[m] && group[m] < 0) { group[m] = serial; todo.push_back(m); }
                }
            }
            const int id = serial++;
            if (int(cells.size()) < min_cells) continue;
            double high = -1e9, low = 1e9;
            for (int c : cells) { high = std::max(high, double(top[c])); low = std::min(low, double(top[c])); }
            // What crosses the group's edge: in from outside, out to where it lands.
            double in = 0.0, outq = 0.0, px = 0.0, py = 0.0, pz = 0.0, pd = 0.0;
            for (int c : cells) {
                const int i = c%w, j = c/w;
                const int nb[4] = {i > 0 ? c-1 : -1, i < w-1 ? c+1 : -1, j > 0 ? c-w : -1, j < h-1 ? c+w : -1};
                // The neighbour's pipe back towards c: -x's +x, +x's -x, -z's +z, +z's -z.
                static const int back[4] = {1, 0, 3, 2};
                for (int k = 0; k < 4; ++k) {
                    const int m = nb[k];
                    if (m < 0 || group[m] == id || kind[m] == OUTSIDE) continue;
                    in += flux[m*4+back[k]];
                    const double q = flux[c*4+k];
                    if (q <= 0.0) continue;
                    outq += q;
                    px += q*(ox+(m%w+0.5)*cell); pz += q*(oz+(m/w+0.5)*cell); py += q*top[m]; pd += q*depth[m];
                }
            }
            const double q = std::max(in, outq);
            if (q < min_flux) continue;
            // The lip: the cells near the top, by depth.
            double lw = 0.0, lx = 0.0, ly = 0.0, lz = 0.0, dx = 0.0, dz = 0.0;
            for (int c : cells) {
                if (top[c] < high-lip_band) continue;
                const double k = depth[c]+1e-4;
                lw += k; lx += k*(ox+(c%w+0.5)*cell); lz += k*(oz+(c/w+0.5)*cell); ly += k*top[c];
                dx += k*vx[c]; dz += k*vz[c];
            }
            lx /= lw; ly /= lw; lz /= lw;
            const double dl = std::sqrt(dx*dx+dz*dz);
            if (dl > 1e-9) { dx /= dl; dz /= dl; } else { dx = 1.0; dz = 0.0; }
            double lo = 1e9, hi = -1e9;
            for (int c : cells) {
                if (top[c] < high-lip_band) continue;
                const double t = (ox+(c%w+0.5)*cell-lx)*-dz+(oz+(c/w+0.5)*cell-lz)*dx;
                lo = std::min(lo, t); hi = std::max(hi, t);
            }
            // The wet channel at the lip may be wider than its steep cells:
            // walk across it from the lip's middle while the water holds.
            double reach_lo = 0.0, reach_hi = 0.0;
            for (int side = -1; side <= 1; side += 2) {
                double run = 0.0;
                for (double d = 0.5*cell; d <= 3.0; d += 0.5*cell) {
                    const int m = index(lx-dz*side*d, lz+dx*side*d);
                    if (m < 0 || kind[m] == OUTSIDE || depth[m] <= wet) break;
                    run = d;
                }
                (side < 0 ? reach_lo : reach_hi) = run;
            }
            const double lip_half = std::max(0.5*(hi-lo), 0.5*(reach_lo+reach_hi))+0.5*cell;
            // Stations down the face: the cells in each band of height.
            const int bands = std::max(1, int(std::ceil((high-low)/band)));
            std::vector<double> sum(size_t(bands)*7, 0.0); // count, x, z, y, xx, zz, xz
            for (int c : cells) {
                const int b = std::min(bands-1, int((high-top[c])/band));
                const double x = ox+(c%w+0.5)*cell, z = oz+(c/w+0.5)*cell;
                double *e = &sum[size_t(b)*7];
                e[0] += 1.0; e[1] += x; e[2] += z; e[3] += top[c]; e[4] += x*x; e[5] += z*z; e[6] += x*z;
            }
            std::vector<Vector4> course;
            std::vector<int> used;
            course.push_back(Vector4(float(lx), float(ly), float(lz), float(lip_half)));
            for (int b = 0; b < bands; ++b) {
                const double *e = &sum[size_t(b)*7];
                if (e[0] < 1.0) continue;
                const double y = e[3]/e[0];
                if (y >= ly-0.05) continue;
                course.push_back(Vector4(float(e[1]/e[0]), float(y), float(e[2]/e[0]), 0.0f));
                used.push_back(b);
            }
            Vector3 plunge;
            if (outq > 0.0) plunge = Vector3(float(px/outq), float(py/outq), float(pz/outq));
            else plunge = Vector3(course.back().x, float(low), course.back().z);
            const double plunge_depth = outq > 0.0 ? pd/outq : 0.0;
            course.push_back(Vector4(plunge.x, plunge.y, plunge.z, 0.0f));
            // Each band's half width across the course there, from its spread.
            for (size_t k = 1; k+1 < course.size(); ++k) {
                const double *e = &sum[size_t(used[k-1])*7];
                const double mx = e[1]/e[0], mz = e[2]/e[0];
                const double sxx = e[4]/e[0]-mx*mx, szz = e[5]/e[0]-mz*mz, sxz = e[6]/e[0]-mx*mz;
                double tx = course[k+1].x-course[k-1].x, tz = course[k+1].z-course[k-1].z;
                const double tl = std::sqrt(tx*tx+tz*tz);
                if (tl > 1e-6) { tx /= tl; tz /= tl; } else { tx = dx; tz = dz; }
                const double ax = -tz, az = tx;
                const double spread = std::max(0.0, sxx*ax*ax+2.0*sxz*ax*az+szz*az*az);
                course[k].w = float(std::sqrt(3.0*spread)+0.5*cell);
            }
            course.back().w = course.size() > 2 ? course[course.size()-2].w : float(lip_half);
            const double drop = ly-plunge.y;
            if (drop < min_drop) continue;
            PackedVector4Array stations;
            for (const Vector4 &v : course) stations.push_back(v);
            Dictionary fall;
            fall["flux"] = q;
            fall["drop"] = drop;
            fall["cells"] = int(cells.size());
            fall["lip"] = Vector3(float(lx), float(ly), float(lz));
            fall["lip_dir"] = Vector2(float(dx), float(dz));
            fall["lip_half"] = lip_half;
            fall["plunge"] = plunge;
            fall["plunge_depth"] = plunge_depth;
            fall["course"] = stations;
            found.push_back({q, fall});
        }
        std::sort(found.begin(), found.end(), [](const Found &a, const Found &b) { return a.flux > b.flux; });
        for (size_t k = 0; k < found.size() && int(k) < most; ++k) out.push_back(found[k].fall);
        return out;
    }

    // The water leaving the plate over each edge cell, m³/s smoothed
    // (`edge_smooth`): {"sides": [-x, +x, -z, +z], each a PackedFloat32Array
    // along its side (by row for the x sides, by column for the z sides),
    // "total"}.
    Dictionary edge_outflow() const {
        Array sides;
        PackedFloat32Array along[4];
        along[0].resize(h); along[1].resize(h); along[2].resize(w); along[3].resize(w);
        for (int s = 0; s < 4; ++s) along[s].fill(0.0f);
        double total = 0.0;
        for (size_t e = 0; e < edge_cells.size(); ++e) {
            const int c = edge_cells[e], s = edge_side[e];
            const int k = s < 2 ? c/w : c%w;
            along[s].set(k, along[s][k]+edge_rate[c]);
            total += edge_rate[c];
        }
        for (int s = 0; s < 4; ++s) sides.push_back(along[s]);
        Dictionary out;
        out["sides"] = sides;
        out["total"] = total;
        return out;
    }

    // Spills off the plate for the edge falls (docs/scenic/water-flow.md
    // "Edge falls"): runs of edge cells along one side each leaving more than
    // `cell_min` m³/s, bridging gaps of up to `gap` cells, that carry
    // `min_flux` m³/s between them. Each spill, the largest first (at most
    // `max`), is {"side" (0 -x, 1 +x, 2 -z, 3 +z), "normal" (Vector2, out of
    // the plate), "flux", "lip" (Vector3 on the rim: the flux-weighted middle
    // of the run, at the water's surface in the cells inward of it), "floor"
    // (the ground at the lip, flux-weighted), "half" (half its width across,
    // from the flux's spread), "from" and "to" (the run's ends along the
    // side, m), "depth" (the brink depth, flux-weighted), "speed" (m/s out of
    // the plate in the cells inward, flux-weighted, at least 0)}.
    Array spills(const Dictionary &p) const {
        const double cell_min = p.get("cell_min", 0.0004), min_flux = p.get("min_flux", 0.003);
        const int gap = p.get("gap", 1), most = p.get("max", 8);
        struct Found { double flux; Dictionary spill; };
        std::vector<Found> found;
        const int count = int(edge_cells.size());
        // Edge cells by side, in order along it.
        std::vector<int> order[4];
        for (int e = 0; e < count; ++e) order[edge_side[e]].push_back(e);
        for (int s = 0; s < 4; ++s) {
            std::vector<int> &list = order[s];
            auto along_of = [&](int e) -> int { const int c = edge_cells[e]; return s < 2 ? c/w : c%w; };
            std::sort(list.begin(), list.end(), [&](int a, int b) { return along_of(a) < along_of(b); });
            size_t k = 0;
            while (k < list.size()) {
                if (edge_rate[edge_cells[list[k]]] <= cell_min) { ++k; continue; }
                // A run: carry on while the next leaving cell is within `gap`.
                size_t end = k;
                for (size_t m = k+1; m < list.size(); ++m) {
                    if (along_of(list[m])-along_of(list[end]) > gap+1) break;
                    if (edge_rate[edge_cells[list[m]]] > cell_min) end = m;
                }
                double q = 0.0, t = 0.0, tt = 0.0, y = 0.0, fl = 0.0, dep = 0.0, sp = 0.0;
                for (size_t m = k; m <= end; ++m) {
                    const int e = list[m], c = edge_cells[e], in = edge_inner[e];
                    const double r = edge_rate[c];
                    const double a = (s < 2 ? oz : ox)+(along_of(e)+0.5)*cell;
                    const double out_speed = s == 0 ? -vx[in] : s == 1 ? vx[in] : s == 2 ? -vz[in] : vz[in];
                    q += r; t += r*a; tt += r*a*a;
                    y += r*std::max(double(ground[in]+depth[in]), double(ground[c]+edge_brink[c]));
                    fl += r*ground[c]; dep += r*edge_brink[c]; sp += r*std::max(0.0, out_speed);
                }
                const double from = (s < 2 ? oz : ox)+along_of(list[k])*cell, to = (s < 2 ? oz : ox)+(along_of(list[end])+1)*cell;
                k = end+1;
                if (q < min_flux) continue;
                const double mid = t/q, spread = std::max(0.0, tt/q-mid*mid);
                const double half = std::min(0.5*(to-from), std::sqrt(3.0*spread)+0.5*cell);
                const double rim_x = s == 0 ? ox : s == 1 ? ox+w*cell : 0.0, rim_z = s == 2 ? oz : s == 3 ? oz+h*cell : 0.0;
                const Vector2 normal = s == 0 ? Vector2(-1, 0) : s == 1 ? Vector2(1, 0) : s == 2 ? Vector2(0, -1) : Vector2(0, 1);
                Dictionary spill;
                spill["side"] = s;
                spill["normal"] = normal;
                spill["flux"] = q;
                spill["lip"] = s < 2 ? Vector3(float(rim_x), float(y/q), float(mid)) : Vector3(float(mid), float(y/q), float(rim_z));
                spill["floor"] = fl/q;
                spill["half"] = half;
                spill["from"] = from;
                spill["to"] = to;
                spill["depth"] = dep/q;
                spill["speed"] = sp/q;
                found.push_back({q, spill});
            }
        }
        std::sort(found.begin(), found.end(), [](const Found &a, const Found &b) { return a.flux > b.flux; });
        Array out;
        for (size_t k = 0; k < found.size() && int(k) < most; ++k) out.push_back(found[k].spill);
        return out;
    }
};
