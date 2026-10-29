#ifndef BLIND_EXACT_SEED_RADIUS_VETO_H
#define BLIND_EXACT_SEED_RADIUS_VETO_H
#include "include/blind_detour.h"
#include "Recast.h"
#include "RecastAlloc.h"
#include <cmath>
#include <cstring>

// Additional exclusion only, over unmodified Recast's frozen boundary seeds.
// Direct bounded integer predicate; no nearest-label inference, EDT, new search
// algorithm, source geometry inflation, or continuous-clearance claim.
// This helper is private to one synchronous build. No global mutable state.
class BNSeedRadiusVeto {
    struct Offset { int x, z; };
    unsigned char* seeds_ = 0;
    unsigned char* originalAreas_ = 0;
    unsigned char* keep_ = 0;
    Offset* offsets_ = 0;
    int width_ = 0, height_ = 0, spans_ = 0, radius_ = 0, offsetCount_ = 0;
    bool prepared_ = false;
    const rcCompactCell* cells_ = 0;
    const rcCompactSpan* spanData_ = 0;
    static bool refuse(BNSeedRadiusVetoReceipt& r, int status) { r.status = status; return false; }
public:
    BNSeedRadiusVeto() = default;
    BNSeedRadiusVeto(const BNSeedRadiusVeto&) = delete;
    BNSeedRadiusVeto& operator=(const BNSeedRadiusVeto&) = delete;
    ~BNSeedRadiusVeto() { rcFree(seeds_); rcFree(originalAreas_); rcFree(keep_); rcFree(offsets_); }

    bool prepare(const rcCompactHeightfield& c, int radius, unsigned long long maxWork,
                 BNSeedRadiusVetoReceipt& r) {
        r.schema = 1; r.work_limit = maxWork;
        if (prepared_ || seeds_ || !c.cells || !c.spans || !c.areas ||
            c.width < 1 || c.height < 1 || c.spanCount < 1 || c.spanCount > 65536 ||
            static_cast<unsigned long long>(c.width) * c.height > 250000 ||
            radius < 1 || radius > 80 || !std::isfinite(c.cs) || !std::isfinite(c.ch) ||
            c.cs <= 0 || c.ch <= 0 || !std::isfinite(c.bmin[0]) ||
            !std::isfinite(c.bmin[1]) || !std::isfinite(c.bmin[2]))
            return refuse(r, BN_SEED_RADIUS_INVALID_INPUT);
        if (!maxWork || maxWork > 10000000ULL) return refuse(r, BN_SEED_RADIUS_WORK_LIMIT);
        width_ = c.width; height_ = c.height; spans_ = c.spanCount; radius_ = radius;
        r.width = width_; r.height = height_; r.span_count = spans_; r.radius_cells = radius_;
        int cursor = 0, commonY = -1;
        // Match the captured domain exactly. Do not flatten stacked spans,
        // choose a convenient floor, repair connectivity, or invent support.
        for (int z = 0; z < height_; ++z) for (int x = 0; x < width_; ++x) {
            const rcCompactCell& cell = c.cells[x + z * width_];
            if (cell.count > 1) return refuse(r, BN_SEED_RADIUS_UNSUPPORTED_LAYER);
            if (static_cast<unsigned long long>(cell.index) + cell.count > static_cast<unsigned>(spans_))
                return refuse(r, BN_SEED_RADIUS_INVALID_TOPOLOGY);
            if (!cell.count) continue; // Absent columns are NOT independent seeds.
            const int i = static_cast<int>(cell.index);
            if (i != cursor++ || c.areas[i] > RC_WALKABLE_AREA)
                return refuse(r, BN_SEED_RADIUS_INVALID_TOPOLOGY);
            const rcCompactSpan& span = c.spans[i];
            if (commonY < 0) commonY = span.y;
            if (commonY != span.y) return refuse(r, BN_SEED_RADIUS_UNSUPPORTED_LAYER);
            for (int d = 0; d < 4; ++d) {
                const int connection = rcGetCon(span, d);
                if (connection == RC_NOT_CONNECTED) continue;
                const int nx = x + rcGetDirOffsetX(d), nz = z + rcGetDirOffsetY(d);
                if (nx < 0 || nx >= width_ || nz < 0 || nz >= height_)
                    return refuse(r, BN_SEED_RADIUS_INVALID_TOPOLOGY);
                const rcCompactCell& neighbor = c.cells[nx + nz * width_];
                if (neighbor.count != 1 || connection != 0 || neighbor.index >= static_cast<unsigned>(spans_))
                    return refuse(r, BN_SEED_RADIUS_INVALID_TOPOLOGY);
                const rcCompactSpan& next = c.spans[neighbor.index];
                if (next.y != span.y) return refuse(r, BN_SEED_RADIUS_UNSUPPORTED_LAYER);
                if (rcGetCon(next, (d + 2) % 4) != 0)
                    return refuse(r, BN_SEED_RADIUS_INVALID_TOPOLOGY);
            }
        }
        if (cursor != spans_) return refuse(r, BN_SEED_RADIUS_INVALID_TOPOLOGY);
        r.common_y_voxel = commonY;
        // R<=80 and dimensions<=250000 make all following integer products
        // representable. Still form byte/work products in wide unsigned types.
        for (int z = -radius_; z <= radius_; ++z) for (int x = -radius_; x <= radius_; ++x)
            if (x*x + z*z < radius_*radius_) ++offsetCount_;
        const unsigned long long padded = static_cast<unsigned long long>(width_ + 2) * (height_ + 2);
        const unsigned long long bytes = padded + 2ULL * spans_ +
            static_cast<unsigned long long>(offsetCount_) * sizeof(Offset);
        if (bytes > 2ULL * 1024 * 1024) return refuse(r, BN_SEED_RADIUS_WORK_LIMIT);
        seeds_ = static_cast<unsigned char*>(rcAlloc(static_cast<size_t>(padded), RC_ALLOC_TEMP));
        originalAreas_ = static_cast<unsigned char*>(rcAlloc(spans_, RC_ALLOC_TEMP));
        keep_ = static_cast<unsigned char*>(rcAlloc(spans_, RC_ALLOC_TEMP));
        offsets_ = static_cast<Offset*>(rcAlloc(static_cast<size_t>(offsetCount_) * sizeof(Offset), RC_ALLOC_TEMP));
        if (!seeds_ || !originalAreas_ || !keep_ || !offsets_)
            return refuse(r, BN_SEED_RADIUS_ALLOCATION_FAILED);
        std::memset(seeds_, 0, static_cast<size_t>(padded));
        std::memcpy(originalAreas_, c.areas, spans_);
        int n = 0;
        for (int z = -radius_; z <= radius_; ++z) for (int x = -radius_; x <= radius_; ++x)
            if (x*x + z*z < radius_*radius_) offsets_[n++] = Offset{x, z};
        const int stride = width_ + 2;
        for (int z = 0; z < height_ + 2; ++z) for (int x = 0; x < width_ + 2; ++x)
            if (x == 0 || z == 0 || x == width_ + 1 || z == height_ + 1) {
                seeds_[x + z * stride] = 1; ++r.exterior_seed_count;
            }
        for (int z = 0; z < height_; ++z) for (int x = 0; x < width_; ++x) {
            const rcCompactCell& cell = c.cells[x + z * width_];
            if (!cell.count) continue;
            const int i = static_cast<int>(cell.index);
            bool seed = c.areas[i] == RC_NULL_AREA;
            for (int d = 0; d < 4; ++d) {
                if (rcGetCon(c.spans[i], d) == RC_NOT_CONNECTED) { seed = true; continue; }
                const int nx = x + rcGetDirOffsetX(d), nz = z + rcGetDirOffsetY(d);
                if (c.areas[c.cells[nx + nz * width_].index] == RC_NULL_AREA) seed = true;
            }
            if (seed) { seeds_[(x + 1) + (z + 1) * stride] = 1; ++r.real_seed_count; }
        }
        cells_ = c.cells; spanData_ = c.spans; prepared_ = true;
        r.status = BN_SEED_RADIUS_PREPARED;
        return true;
    }

    // Call only immediately after stock rcErodeWalkableArea on this private
    // compact field. Stock erosion changes areas, not cells/spans/topology.
    bool apply(rcCompactHeightfield& c, BNSeedRadiusVetoReceipt& r) {
        if (!prepared_ || r.status != BN_SEED_RADIUS_PREPARED || c.width != width_ ||
            c.height != height_ || c.spanCount != spans_ || c.cells != cells_ || c.spans != spanData_ || !c.areas)
            return refuse(r, BN_SEED_RADIUS_INVALID_TOPOLOGY);
        for (int i = 0; i < spans_; ++i) {
            if (c.areas[i] != RC_NULL_AREA && c.areas[i] != originalAreas_[i])
                return refuse(r, BN_SEED_RADIUS_INVALID_TOPOLOGY); // No stock promotion/change.
            if (c.areas[i] != RC_NULL_AREA) ++r.stock_keep_count;
            keep_[i] = 0;
        }
        r.work_bound = static_cast<unsigned long long>(r.stock_keep_count) * offsetCount_;
        if (r.work_bound > r.work_limit) return refuse(r, BN_SEED_RADIUS_WORK_LIMIT);
        const int stride = width_ + 2;
        for (int z = 0; z < height_; ++z) for (int x = 0; x < width_; ++x) {
            const rcCompactCell& cell = c.cells[x + z * width_];
            if (!cell.count || c.areas[cell.index] == RC_NULL_AREA) continue;
            bool keep = true;
            for (int k = 0; k < offsetCount_; ++k) {
                ++r.work_performed; // Counts bounded tests even if outside the padded bitmap.
                const int nx = x + 1 + offsets_[k].x, nz = z + 1 + offsets_[k].z;
                if (nx < 0 || nx >= width_ + 2 || nz < 0 || nz >= height_ + 2) continue;
                if (seeds_[nx + nz * stride]) { keep = false; break; }
            }
            keep_[cell.index] = keep ? 1 : 0;
            if (keep) ++r.exact_keep_count;
        }
        // Commit only after the entire bounded predicate is complete. Never
        // resurrect a stock-null span; equality at R^2 was never in the kernel.
        for (int i = 0; i < spans_; ++i) if (!keep_[i]) c.areas[i] = RC_NULL_AREA;
        r.additional_rejected_count = r.stock_keep_count - r.exact_keep_count;
        r.status = BN_SEED_RADIUS_APPLIED; prepared_ = false;
        return true;
    }
};
#endif
