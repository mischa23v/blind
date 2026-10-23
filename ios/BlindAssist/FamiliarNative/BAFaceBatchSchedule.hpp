#pragma once
#include <algorithm>
#include <vector>

namespace ba_face {
// Resource policy only, not a face association/tracking algorithm. A stable spatial
// order is supplied anew for each frame; these slots never become identity IDs.
inline std::vector<int> slots(int detected, long start) {
    if (detected <= 0 || detected > 32) return {};
    const int offset = static_cast<int>(std::max(0L, start) % detected);
    std::vector<int> result;
    for (int i = 0; i < std::min(2, detected); ++i) result.push_back((offset + i) % detected);
    return result;
}
}
