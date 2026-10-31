// Copyright NumFOCUS. Licensed under Apache-2.0; see ../LICENSE and ../NOTICE.
// MODIFIED 2026-10-29: research-only adaptation of ITK Voronoi/Remove at
// 2e353bf3975631defae25f1432e3333d97ff0a95. Not an upstream ITK integer API.
// Removed image/contour/sign/spacing/thread framework; supplied original binary
// seeds, two integer passes, caller-owned buffers and explicit resource guards.
// UNCOMPILED / UNVALIDATED. No production caller or fallback.
#ifndef RESEARCH_SEED_DISTANCE_MAURER_H
#define RESEARCH_SEED_DISTANCE_MAURER_H
#include <cstddef>
#include <cstdint>
#include <limits>

namespace research_maurer {
using I = std::int64_t;
using U = std::uint64_t;
constexpr I infinity = (std::numeric_limits<I>::max)();
enum class Status { ok, invalid, capacity, memory_limit, work_limit };
struct Receipt { U work = 0, bound = 0, accountedBytes = 0; };
struct Buffers {
    // All six buffers must be mutually disjoint, correctly aligned and live.
    // Counted capacities are element counts, not bytes. No allocation occurs.
    const std::uint8_t* seeds; const std::uint8_t* originalKeep;
    std::uint8_t* keep; I* distance; I* g; I* h;
    std::size_t maskCapacity, distanceCapacity, lineCapacity;
};

// Upstream Remove predicate, specialized to finite nonnegative squared costs.
// Input checks below bound all four terms and every partial sum by 4*L^3.
inline bool remove(I d1, I d2, I df, I x1, I x2, I xf) noexcept {
    const I a = x2-x1, b = xf-x2, c = xf-x1;
    const I value = c*d2 - b*d1 - a*df - a*b*c;
    return value > 0; // Preserve upstream strict tie semantics.
}
inline bool tick(Receipt& r, U limit) noexcept {
    if (r.work == limit) return false;
    ++r.work; return true;
}
inline bool line(I* d, std::size_t n, std::size_t stride, I* g, I* h,
                 Receipt& r, U limit) noexcept {
    I l = -1;
    for (std::size_t i=0; i<n; ++i) {
        if (!tick(r,limit)) return false;
        const I di=d[i*stride], iw=static_cast<I>(i);
        if (di==infinity) continue;
        if (l>=1) {
            while (l>=1) {
                if (!tick(r,limit)) return false;
                if (!remove(g[l-1],g[l],di,h[l-1],h[l],iw)) break;
                --l;
            }
        }
        ++l; g[l]=di; h[l]=iw;
    }
    if (l==-1) return true; // No finite site: leave sentinel line unchanged.
    const I ns=l; l=0;
    for (std::size_t i=0; i<n; ++i) {
        if (!tick(r,limit)) return false;
        const I iw=static_cast<I>(i), delta=h[l]-iw;
        I d1=g[l]+delta*delta;
        while (l<ns) {
            if (!tick(r,limit)) return false;
            const I delta2=h[l+1]-iw, d2=g[l+1]+delta2*delta2;
            if (d1<=d2) break; // Keep upstream tie behavior, not nearest labels.
            ++l; d1=d2;
        }
        d[i*stride]=d1;
    }
    return true;
}

// Dimensions include the caller's unchanged one-cell exterior seed perimeter.
// Caller must retain existing Recast flat-layer/topology/span checks BEFORE this
// helper. originalKeep is stock keep projected to the same padded grid; absent
// columns and padding have originalKeep=0. No geometry is accepted by this API.
// additionalLiveBytes accounts for caller-owned original span areas/other live
// adapter scratch, so the existing 2 MiB total temporary-memory limit is retained.
// It MUST include capacity slack, canaries and allocation overhead. The receipt
// is declared buffer accounting, not actual RSS or a heap sandbox guarantee.
// On non-ok, keep is untouched; scratch distance/g/h may be modified.
inline Status transform(std::size_t width, std::size_t height, unsigned radius,
                        U maxWork, U additionalLiveBytes, Buffers b,
                        Receipt& r) noexcept {
    r=Receipt{};
    if (!width || !height || width>250000 || height>250000 ||
        !radius || radius>80 || !b.seeds || !b.originalKeep || !b.keep ||
        !b.distance || !b.g || !b.h) return Status::invalid;
    // Deliberately stricter than current unpadded cell cap, never an expansion.
    if (width>250000/height) return Status::capacity;
    const std::size_t n=width*height, length=width>height?width:height;
    if (b.maskCapacity<n || b.distanceCapacity<n || b.lineCapacity<length)
        return Status::capacity;
    const U L=static_cast<U>(length), imax=static_cast<U>(infinity);
    // Checked cubic bound, not merely checking final squared distances.
    if (L>imax/L || L*L>imax/L || L*L*L>imax/4) return Status::capacity;
    const U bytes=11ULL*n+16ULL*length; // three byte masks + int64 image + g/h
    constexpr U byteLimit=2ULL*1024*1024;
    if (bytes>byteLimit || additionalLiveBytes>byteLimit-bytes)
        return Status::memory_limit;
    r.accountedBytes=bytes+additionalLiveBytes;
    r.bound=14ULL*n; // init + 2*(build + <=2 prune + eval + <=2 advance) + commit
    if (!maxWork || maxWork>10000000ULL || r.bound>maxWork)
        return Status::work_limit;
    for (std::size_t i=0; i<n; ++i) {
        if (!tick(r,maxWork)) return Status::work_limit;
        if (b.seeds[i]>1 || b.originalKeep[i]>1) return Status::invalid;
        b.distance[i]=b.seeds[i]?0:infinity;
    }
    for (std::size_t y=0; y<height; ++y)
        if (!line(b.distance+y*width,width,1,b.g,b.h,r,maxWork))
            return Status::work_limit;
    for (std::size_t x=0; x<width; ++x)
        if (!line(b.distance+x,height,width,b.g,b.h,r,maxWork))
            return Status::work_limit;
    if (r.work>maxWork-n) return Status::work_limit;
    const I r2=static_cast<I>(radius)*radius;
    for (std::size_t i=0; i<n; ++i) {
        b.keep[i]=static_cast<std::uint8_t>(b.originalKeep[i] && b.distance[i]>=r2);
    }
    r.work+=n;
    return Status::ok;
}
} // namespace research_maurer
#endif
