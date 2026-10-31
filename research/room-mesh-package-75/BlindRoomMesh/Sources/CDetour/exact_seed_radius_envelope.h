#ifndef BLIND_EXACT_SEED_RADIUS_ENVELOPE_H
#define BLIND_EXACT_SEED_RADIUS_ENVELOPE_H
#include "include/blind_detour.h"
#include "Recast.h"
#include "RecastAlloc.h"
#include "Envelope/candidate/seed_distance_maurer.h"
#include <cmath>
#include <cstring>

// New policy only. Old integer-disk helper and schema1 are retained unchanged.
// Original topology checks and seed loops below copied from the frozen old helper.
class BNSeedRadiusEnvelope {
    unsigned char *seeds_=0, *originalAreas_=0, *stockGrid_=0, *keepGrid_=0;
    research_maurer::I *distance_=0,*g_=0,*h_=0;
    int width_=0,height_=0,spans_=0,radius_=0;
    size_t padded_=0,lineLength_=0;
    bool prepared_=false,attempted_=false;
    const rcCompactCell* cells_=0;
    const rcCompactSpan* spanData_=0;
    static bool refuse(BNSeedRadiusEnvelopeReceipt& r,int status){r.status=status;return false;}
public:
    BNSeedRadiusEnvelope()=default;
    BNSeedRadiusEnvelope(const BNSeedRadiusEnvelope&)=delete;
    BNSeedRadiusEnvelope& operator=(const BNSeedRadiusEnvelope&)=delete;
    ~BNSeedRadiusEnvelope(){rcFree(seeds_);rcFree(originalAreas_);rcFree(stockGrid_);rcFree(keepGrid_);rcFree(distance_);rcFree(g_);rcFree(h_);}
    bool prepare(const rcCompactHeightfield& c,int radius,unsigned long long maxWork,
                 BNSeedRadiusEnvelopeReceipt& r){
        r.schema=2;r.algorithm=BN_ENVELOPE_MAURER_INT64_V1;
        r.work_unit=BN_ENVELOPE_LOOP_VISIT_OR_COMPARISON_V1;r.work_limit=maxWork;
        if(attempted_)return refuse(r,BN_SEED_RADIUS_INVALID_INPUT);
        attempted_=true; // One owner/attempt, including partially allocated failures.
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

        const unsigned long long padded=static_cast<unsigned long long>(width_+2)*(height_+2);
        const unsigned long long length=width_>height_?width_+2:height_+2;
        if(padded>250000) return refuse(r,BN_ENVELOPE_MEMORY_LIMIT);
        // Seven allocations: reserve64 bytes bookkeeping each, not a heap/RSS proof.
        const unsigned long long bytes=11ULL*padded+16ULL*length+spans_+448ULL;
        r.padded_cell_count=padded;r.workspace_bytes_declared=bytes;r.work_bound=14ULL*padded;
        if(bytes>2ULL*1024*1024) return refuse(r,BN_ENVELOPE_MEMORY_LIMIT);
        if(r.work_bound>maxWork) return refuse(r,BN_SEED_RADIUS_WORK_LIMIT);
        padded_=static_cast<size_t>(padded);lineLength_=static_cast<size_t>(length);
        seeds_=static_cast<unsigned char*>(rcAlloc(padded_,RC_ALLOC_TEMP));
        originalAreas_=static_cast<unsigned char*>(rcAlloc(spans_,RC_ALLOC_TEMP));
        stockGrid_=static_cast<unsigned char*>(rcAlloc(padded_,RC_ALLOC_TEMP));
        keepGrid_=static_cast<unsigned char*>(rcAlloc(padded_,RC_ALLOC_TEMP));
        distance_=static_cast<research_maurer::I*>(rcAlloc(8*padded_,RC_ALLOC_TEMP));
        g_=static_cast<research_maurer::I*>(rcAlloc(8*lineLength_,RC_ALLOC_TEMP));
        h_=static_cast<research_maurer::I*>(rcAlloc(8*lineLength_,RC_ALLOC_TEMP));
        if(!seeds_||!originalAreas_||!stockGrid_||!keepGrid_||!distance_||!g_||!h_)
            return refuse(r,BN_SEED_RADIUS_ALLOCATION_FAILED);
        std::memset(seeds_,0,padded_);std::memset(stockGrid_,0,padded_);
        std::memcpy(originalAreas_,c.areas,spans_);
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

        cells_=c.cells;spanData_=c.spans;prepared_=true;
        r.status=BN_SEED_RADIUS_PREPARED;return true;
    }
    bool apply(rcCompactHeightfield& c,BNSeedRadiusEnvelopeReceipt& r){
        if(!prepared_||r.schema!=2||r.algorithm!=BN_ENVELOPE_MAURER_INT64_V1||
           r.work_unit!=BN_ENVELOPE_LOOP_VISIT_OR_COMPARISON_V1||
           r.status!=BN_SEED_RADIUS_PREPARED||c.width!=width_||c.height!=height_||
           c.spanCount!=spans_||c.cells!=cells_||c.spans!=spanData_||!c.areas)
            return refuse(r,BN_SEED_RADIUS_INVALID_TOPOLOGY);
        for(int i=0;i<spans_;++i){
            if(c.areas[i]!=RC_NULL_AREA&&c.areas[i]!=originalAreas_[i])
                return refuse(r,BN_SEED_RADIUS_INVALID_TOPOLOGY);
            if(c.areas[i]!=RC_NULL_AREA)++r.stock_keep_count;
        }
        const int stride=width_+2;
        for(int z=0;z<height_;++z)for(int x=0;x<width_;++x){
            const rcCompactCell& cell=c.cells[x+z*width_];
            if(cell.count)stockGrid_[(x+1)+(z+1)*stride]=c.areas[cell.index]!=RC_NULL_AREA;
        }
        research_maurer::Buffers b{seeds_,stockGrid_,keepGrid_,distance_,g_,h_,padded_,padded_,lineLength_};
        research_maurer::Receipt k;
        const auto status=research_maurer::transform(width_+2,height_+2,radius_,r.work_limit,
            static_cast<unsigned long long>(spans_)+448ULL,b,k);
        r.work_bound=k.bound;r.work_performed=k.work;r.workspace_bytes_declared=k.accountedBytes;
        if(status!=research_maurer::Status::ok)
            return refuse(r,status==research_maurer::Status::work_limit?BN_SEED_RADIUS_WORK_LIMIT:
                status==research_maurer::Status::memory_limit?BN_ENVELOPE_MEMORY_LIMIT:BN_ENVELOPE_KERNEL_REFUSED);
        for(int z=0;z<height_;++z)for(int x=0;x<width_;++x){
            const rcCompactCell& cell=c.cells[x+z*width_];if(!cell.count)continue;
            if(keepGrid_[(x+1)+(z+1)*stride])++r.exact_keep_count;
        }
        // Only commit after every transform and validation succeeded.
        for(int z=0;z<height_;++z)for(int x=0;x<width_;++x){
            const rcCompactCell& cell=c.cells[x+z*width_];if(!cell.count)continue;
            if(!keepGrid_[(x+1)+(z+1)*stride])c.areas[cell.index]=RC_NULL_AREA;
        }
        r.additional_rejected_count=r.stock_keep_count-r.exact_keep_count;
        r.status=BN_SEED_RADIUS_APPLIED;prepared_=false;return true;
    }
#ifdef BN_ENVELOPE_TEST_OBSERVER
    const unsigned char* frozenSeeds()const{return seeds_;}
    size_t paddedCells()const{return padded_;}
#endif
};
#endif
