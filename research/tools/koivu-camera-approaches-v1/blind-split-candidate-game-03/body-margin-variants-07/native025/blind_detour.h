#ifndef BLIND_DETOUR_H
#define BLIND_DETOUR_H
#ifdef __cplusplus
extern "C" {
#endif
/* Local, simulation-stage adapter. +Y up; metres; no physical clearance claim. */
typedef struct BNConfig {
    float radius, height, cell_size, cell_height, max_climb, max_slope;
    int max_cells, max_nodes;
} BNConfig;
void* bn_build(const float* vertices, int vertex_count, const int* triangles,
               int triangle_count, const BNConfig* config);
void bn_destroy(void* handle);
const char* bn_last_error(void);
/* Returns point count, or -1 on error. complete=0 includes partial/truncated paths.
   Query projections are outputs ONLY: caller must not teleport physical state. */
int bn_path(void* handle, const float* start, const float* goal,
            const float* query_half_extents, float* points, int max_points,
            float* projected_start, float* projected_goal,
            unsigned int* status, int* complete);
/* Upstream velocity sampler; candidate ONLY, not delayed-body clearance.
   circles: x,y,z,r,vx,vy,vz; segments: ax,ay,az,bx,by,bz. */
int bn_velocity(const float* pos, float radius, float vmax,
                const float* velocity, const float* desired, float horizon,
                const float* circles, int circle_count,
                const float* segments, int segment_count, float* output);
#ifdef __cplusplus
}
#endif
#endif
