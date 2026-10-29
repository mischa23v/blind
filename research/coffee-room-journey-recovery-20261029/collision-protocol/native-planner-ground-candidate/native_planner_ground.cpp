// SOURCE ONLY. Thin C ABI for the existing pinned Recast implementation.
// No triangle-normal implementation, mesh mutation, allocation or slope knob.
#include "Recast.h"
#include <cmath>

static_assert(sizeof(float) == 4, "32-bit float ABI required");
static_assert(sizeof(int) == 4, "32-bit int ABI required");

extern "C" int coffee_mark_walkable_15_abi_version() noexcept { return 1; }
extern "C" float coffee_mark_walkable_15_slope_degrees() noexcept { return 15.0f; }

// The caller owns valid non-overlapping buffers: 3*vertex_count floats,
// 3*triangle_count ints, and triangle_count output bytes. Original triangle
// ordering and winding are retained. No physical-support authority is implied.
extern "C" int coffee_mark_walkable_15(const float* vertices, int vertex_count,
                                      const int* triangles, int triangle_count,
                                      unsigned char* eligibility) noexcept {
    constexpr int maximum_count = 2000000;
    if (!vertices || vertex_count <= 0 || vertex_count > maximum_count ||
        triangle_count < 0 || triangle_count > maximum_count ||
        (triangle_count && (!triangles || !eligibility))) return -1;
    // Match the existing Coffee native planner's finite/coordinate domain.
    for (int i = 0; i < vertex_count * 3; ++i)
        if (!std::isfinite(vertices[i]) || std::fabs(vertices[i]) > 10000.0f)
            return -2;
    for (int i = 0; i < triangle_count * 3; ++i)
        if (triangles[i] < 0 || triangles[i] >= vertex_count) return -3;
    if (!triangle_count) return 0;
    for (int i = 0; i < triangle_count; ++i) eligibility[i] = RC_NULL_AREA;
    try {
        // Published function ignores context; do not construct a second engine.
        rcMarkWalkableTriangles(nullptr, 15.0f, vertices, vertex_count,
                                triangles, triangle_count, eligibility);
        for (int i = 0; i < triangle_count; ++i)
            eligibility[i] = eligibility[i] == RC_WALKABLE_AREA ? 1 : 0;
        return 0;
    } catch (...) {
        // Never allow C++ exceptions across the C/ctypes boundary.
        for (int i = 0; i < triangle_count; ++i) eligibility[i] = 0;
        return -4;
    }
}
