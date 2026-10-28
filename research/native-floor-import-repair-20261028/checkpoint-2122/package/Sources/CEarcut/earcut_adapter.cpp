#include "blind_earcut.h"
#include <array>
#include <cmath>
#include <cstdint>
#include <vector>
#include "upstream/mapbox/earcut.hpp"

extern "C" int32_t bn_earcut_simple_ring(const double* xy, int32_t vertex_count,
                                          int32_t* indices, int32_t capacity) {
    if (!xy || !indices || vertex_count < 3 || vertex_count > 1024 ||
        capacity < 3 * (vertex_count - 2) || capacity > 3 * (1024 - 2)) return -1;
    for (int32_t i = 0; i < vertex_count * 2; ++i) {
        if (!std::isfinite(xy[i])) return -1;
    }
    try {
        // One already validated simple ring; no holes, smoothing, snapped
        // coordinates, Delaunay refinement or generated vertices are used.
        std::vector<std::vector<std::array<double, 2>>> polygon(1);
        polygon[0].reserve(static_cast<std::size_t>(vertex_count));
        for (int32_t i = 0; i < vertex_count; ++i) polygon[0].push_back({{xy[2*i], xy[2*i+1]}});
        const auto result = mapbox::earcut<uint32_t>(polygon);
        if (result.empty() || result.size() % 3 != 0 || result.size() > static_cast<std::size_t>(capacity)) return -1;
        for (const auto index : result) if (index >= static_cast<uint32_t>(vertex_count)) return -1;
        for (std::size_t i = 0; i < result.size(); ++i) indices[i] = static_cast<int32_t>(result[i]);
        return static_cast<int32_t>(result.size());
    } catch (...) {
        // No C++ exception crosses the C/Swift boundary.
        return -2;
    }
}
