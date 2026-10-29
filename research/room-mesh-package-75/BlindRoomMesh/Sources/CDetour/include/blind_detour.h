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
/* Explicit source classification per triangle: 0=obstacle, 1=original floor.
   All triangles obstruct; only original-floor triangles may become walkable.
   Null/malformed classification is rejected, never slope-only fallback. */
void* bn_build_classified(const float* vertices, int vertex_count, const int* triangles,
                         int triangle_count, const BNConfig* config,
                         const unsigned char* triangle_support);
/* Opt-in flat-layer discrete seed-radius exclusion. Not source-wall clearance,
   continuous motion validity, floor support or physical output authority.
   Stock APIs/defaults remain unchanged. R = ceil(original radius/cell size).
   Threshold is strict: remove iff squared integer seed distance < R*R. */
enum BNSeedRadiusStatus {
    BN_SEED_RADIUS_NOT_REQUESTED = 0, BN_SEED_RADIUS_PREPARED = 1,
    BN_SEED_RADIUS_APPLIED = 2, BN_SEED_RADIUS_INVALID_INPUT = -1,
    BN_SEED_RADIUS_UNSUPPORTED_LAYER = -2, BN_SEED_RADIUS_INVALID_TOPOLOGY = -3,
    BN_SEED_RADIUS_WORK_LIMIT = -4, BN_SEED_RADIUS_ALLOCATION_FAILED = -5,
    BN_SEED_RADIUS_BUILD_FAILED = -6
};
typedef struct BNSeedRadiusVetoReceipt {
    int schema, status, width, height, span_count, radius_cells, common_y_voxel;
    int real_seed_count, exterior_seed_count, stock_keep_count, exact_keep_count;
    int additional_rejected_count, build_succeeded;
    unsigned long long work_limit, work_bound, work_performed;
} BNSeedRadiusVetoReceipt;
/* maximum_seed_tests must be 1...10,000,000. Budget refusal emits no handle;
   no stock-policy fallback. On later build failure status may still be APPLIED
   with build_succeeded=0, including a valid empty keep mask. */
void* bn_build_classified_seed_radius(const float* vertices, int vertex_count,
    const int* triangles, int triangle_count, const BNConfig* config,
    const unsigned char* triangle_support, unsigned long long maximum_seed_tests,
    BNSeedRadiusVetoReceipt* receipt);
/* Separate schema2 policy. Does NOT reinterpret schema1 seed-test budgets.
   Same flat-layer original-seed predicate; different envelope work units. */
enum BNEnvelopeAlgorithm { BN_ENVELOPE_MAURER_INT64_V1 = 1 };
enum BNEnvelopeWorkUnit { BN_ENVELOPE_LOOP_VISIT_OR_COMPARISON_V1 = 1 };
enum BNEnvelopeExtraStatus { BN_ENVELOPE_MEMORY_LIMIT = -7, BN_ENVELOPE_KERNEL_REFUSED = -8 };
typedef struct BNSeedRadiusEnvelopeReceipt {
    int schema, algorithm, work_unit;
    int status, width, height, span_count, radius_cells, common_y_voxel;
    int real_seed_count, exterior_seed_count, stock_keep_count, exact_keep_count;
    int additional_rejected_count, build_succeeded;
    unsigned long long work_limit, work_bound, work_performed;
    unsigned long long padded_cell_count, workspace_bytes_declared;
} BNSeedRadiusEnvelopeReceipt;
/* maximum_envelope_work counts only kernel init/commit visits, line input/output
   visits and envelope comparisons; excludes topology/seed packing/build stages.
   Limit1...10M. Typed refusal/no handle; never fallback to disk or stock.
   Status codes0..2 and-1..-6 share BNSeedRadiusStatus meanings, not schema/units. */
void* bn_build_classified_seed_radius_envelope(const float* vertices, int vertex_count,
    const int* triangles, int triangle_count, const BNConfig* config,
    const unsigned char* triangle_support, unsigned long long maximum_envelope_work,
    BNSeedRadiusEnvelopeReceipt* receipt);
void* bn_build_excluded(const float* vertices,int vertex_count,const int* triangles,int triangle_count,const BNConfig* config,const float* polygon,int count,float observed_min_y,float observed_max_y);
int bn_excluded_span_count(void* handle);
void bn_destroy(void* handle);
const char* bn_last_error(void);
/* Returns point count, or -1 on error. complete=0 includes partial/truncated paths.
   Query projections are outputs ONLY: caller must not teleport physical state. */
int bn_path(void* handle, const float* start, const float* goal,
            const float* query_half_extents, float* points, int max_points,
            float* projected_start, float* projected_goal,
            unsigned int* status, int* complete);
/* Opt-in requested-XZ admission, NOT physical clearance/support. Legacy bn_path
   is unchanged. Receipts are initialized on every call; an argument/admission
   refusal returns -1, emits no route points and leaves route status/complete at
   zero. After admission, downstream path failures retain bn_path status. */
typedef struct BNEndpointAssociation {
    int found, is_over_polygon;
    float projected[3];
    unsigned int status;
} BNEndpointAssociation;
int bn_path_strict(void* handle, const float* start, const float* goal,
                   const float* query_half_extents, float* points, int max_points,
                   float* projected_start, float* projected_goal,
                   unsigned int* status, int* complete,
                   BNEndpointAssociation* start_association,
                   BNEndpointAssociation* goal_association);
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
