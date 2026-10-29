#ifndef BN_RESEARCH_SINGLE_SPAN_HEIGHTFIELD_ENVELOPE_H
#define BN_RESEARCH_SINGLE_SPAN_HEIGHTFIELD_ENVELOPE_H
#include "../maurer-native-adapter-result-20261029/native/CDetour/include/blind_detour.h"
#include "Recast.h"
#include "RecastAlloc.h"
#include "../maurer-native-adapter-result-20261029/native/CDetour/Envelope/candidate/seed_distance_maurer.h"
#include <cmath>
#include <cstring>

// RESEARCH ONLY. Rebuilt from published flat helper; NOT the lost candidate.
// No production symbol, policy, caller, or inherited validation result.
// Original seed loops/kernel retained; only domain validation and ownership differ.
struct BNResearchHeightfieldReceipt {
    int schema, algorithm, work_unit;
    int status, width, height, span_count, radius_cells, common_y_voxel;
    int real_seed_count, exterior_seed_count, stock_keep_count, exact_keep_count;
    int additional_rejected_count, build_succeeded;
    unsigned long long work_limit, work_bound, work_performed;
    unsigned long long padded_cell_count, workspace_bytes_declared;
};
class BNResearchHeightfieldEnvelope {
    unsigned char *seeds_=0, *originalAreas_=0, *stockGrid_=0, *keepGrid_=0;
    research_maurer::I *distance_=0,*g_=0,*h_=0;
    int width_=0,height_=0,spans_=0,radius_=0;
    size_t padded_=0,lineLength_=0;
    bool prepared_=false,attempted_=false;
    const rcCompactCell* cells_=0;
    const rcCompactSpan* spanData_=0;
    const rcCompactHeightfield* owner_=0;
    const unsigned char* areas_=0;
    rcCompactCell* frozenCells_=0;
    rcCompactSpan* frozenSpans_=0;
    const BNResearchHeightfieldReceipt* receiptOwner_=0;
    BNResearchHeightfieldReceipt frozenReceipt_{};
    unsigned long long limit_=0, additionalBytes_=0;
    float cs_=0,ch_=0,bmin_[3]{},bmax_[3]{};
    int walkHeight_=0,climb_=0,border_=0;
    unsigned short maxDistance_=0,maxRegions_=0;
    const unsigned short* dist_=0;
    bool metadataMatches(const rcCompactHeightfield& c) const {
        return &c==owner_ && c.width==width_ && c.height==height_ &&
            c.spanCount==spans_ && c.cells==cells_ && c.spans==spanData_ &&
            c.areas==areas_ && c.cs==cs_ && c.ch==ch_ &&
            c.walkableHeight==walkHeight_ && c.walkableClimb==climb_ &&
            c.borderSize==border_ && c.maxDistance==maxDistance_ &&
            c.maxRegions==maxRegions_ && c.dist==dist_ &&
            !std::memcmp(c.bmin,bmin_,sizeof bmin_) && !std::memcmp(c.bmax,bmax_,sizeof bmax_);
    }
    bool receiptMatches(const BNResearchHeightfieldReceipt& r) const {
#define BN_MATCH(field) if(r.field!=frozenReceipt_.field)return false
        BN_MATCH(schema);BN_MATCH(algorithm);BN_MATCH(work_unit);BN_MATCH(status);
        BN_MATCH(width);BN_MATCH(height);BN_MATCH(span_count);BN_MATCH(radius_cells);
        BN_MATCH(common_y_voxel);BN_MATCH(real_seed_count);BN_MATCH(exterior_seed_count);
        BN_MATCH(stock_keep_count);BN_MATCH(exact_keep_count);BN_MATCH(additional_rejected_count);
        BN_MATCH(build_succeeded);BN_MATCH(work_limit);BN_MATCH(work_bound);BN_MATCH(work_performed);
        BN_MATCH(padded_cell_count);BN_MATCH(workspace_bytes_declared);
#undef BN_MATCH
        return true;
    }
    static bool refuse(BNResearchHeightfieldReceipt& r,int status){r.status=status;return false;}
public:
    BNResearchHeightfieldEnvelope()=default;
    BNResearchHeightfieldEnvelope(const BNResearchHeightfieldEnvelope&)=delete;
    BNResearchHeightfieldEnvelope& operator=(const BNResearchHeightfieldEnvelope&)=delete;
    ~BNResearchHeightfieldEnvelope(){rcFree(seeds_);rcFree(originalAreas_);rcFree(stockGrid_);rcFree(keepGrid_);rcFree(distance_);rcFree(g_);rcFree(h_);rcFree(frozenCells_);rcFree(frozenSpans_);}
    bool prepare(const rcCompactHeightfield& c,int radius,unsigned long long maxWork,
                 BNResearchHeightfieldReceipt& r){
        if(attempted_)return refuse(r,BN_SEED_RADIUS_INVALID_INPUT);
        std::memset(&r,0,sizeof r);
        r.schema=4;r.algorithm=BN_ENVELOPE_MAURER_INT64_V1;
        r.work_unit=BN_ENVELOPE_LOOP_VISIT_OR_COMPARISON_V1;r.work_limit=maxWork;
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
        for(int axis=0;axis<3;++axis)
            if(!std::isfinite(c.bmin[axis]) || !std::isfinite(c.bmax[axis]) ||
               !(c.bmax[axis]>c.bmin[axis]))return refuse(r,BN_SEED_RADIUS_INVALID_INPUT);
        // Match released rcCalcGridSize nearest-integer arithmetic exactly,
        // with finite/range guards before its integer cast.
        const float gridX=(c.bmax[0]-c.bmin[0])/c.cs+0.5f;
        const float gridZ=(c.bmax[2]-c.bmin[2])/c.cs+0.5f;
        if(!std::isfinite(gridX)||!std::isfinite(gridZ)||gridX<1||gridZ<1||
           gridX>250001||gridZ>250001||int(gridX)!=c.width||int(gridZ)!=c.height)
            return refuse(r,BN_SEED_RADIUS_INVALID_INPUT);
        if(c.walkableHeight<1 || c.walkableHeight>255 || c.walkableClimb<0 ||
           c.walkableClimb>65535 || c.borderSize<0)
            return refuse(r,BN_SEED_RADIUS_INVALID_INPUT);
        int cursor = 0;
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
            if(span.h<c.walkableHeight)return refuse(r,BN_SEED_RADIUS_INVALID_TOPOLOGY);

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
                // Released Recast.cpp rcBuildCompactHeightfield overlap/climb rule.
                const int bot = span.y > next.y ? span.y : next.y;
                const int top = span.y+span.h < next.y+next.h ? span.y+span.h : next.y+next.h;
                if(top-bot < c.walkableHeight || std::abs(int(next.y)-int(span.y))>c.walkableClimb)
                    return refuse(r,BN_SEED_RADIUS_INVALID_TOPOLOGY);
                if (rcGetCon(next, (d + 2) % 4) != 0)
                    return refuse(r, BN_SEED_RADIUS_INVALID_TOPOLOGY);
            }
        }
        if (cursor != spans_) return refuse(r, BN_SEED_RADIUS_INVALID_TOPOLOGY);
        r.common_y_voxel = -1; // Variable quantized Y, never a flattened common floor.

        const unsigned long long padded=static_cast<unsigned long long>(width_+2)*(height_+2);
        const unsigned long long length=width_>height_?width_+2:height_+2;
        if(padded>250000) return refuse(r,BN_ENVELOPE_MEMORY_LIMIT);
        // Nine allocations plus fixed bookkeeping reserve; declared bytes, not RSS.
        additionalBytes_=static_cast<unsigned long long>(spans_)*(1+sizeof(rcCompactSpan))+
            static_cast<unsigned long long>(width_)*height_*sizeof(rcCompactCell)+576ULL;
        const unsigned long long bytes=11ULL*padded+16ULL*length+additionalBytes_;
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
        frozenCells_=static_cast<rcCompactCell*>(rcAlloc(sizeof(rcCompactCell)*width_*height_,RC_ALLOC_TEMP));
        frozenSpans_=static_cast<rcCompactSpan*>(rcAlloc(sizeof(rcCompactSpan)*spans_,RC_ALLOC_TEMP));
        if(!frozenCells_||!frozenSpans_||!seeds_||!originalAreas_||!stockGrid_||!keepGrid_||!distance_||!g_||!h_)
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

        std::memcpy(frozenCells_,c.cells,sizeof(rcCompactCell)*width_*height_);
        std::memcpy(frozenSpans_,c.spans,sizeof(rcCompactSpan)*spans_);
        cells_=c.cells;spanData_=c.spans;areas_=c.areas;owner_=&c;
        cs_=c.cs;ch_=c.ch;std::memcpy(bmin_,c.bmin,sizeof bmin_);std::memcpy(bmax_,c.bmax,sizeof bmax_);
        walkHeight_=c.walkableHeight;climb_=c.walkableClimb;border_=c.borderSize;
        maxDistance_=c.maxDistance;maxRegions_=c.maxRegions;dist_=c.dist;
        limit_=maxWork;prepared_=true;receiptOwner_=&r;
        r.status=BN_SEED_RADIUS_PREPARED;
        std::memcpy(&frozenReceipt_,&r,sizeof r);return true;
    }
    bool apply(rcCompactHeightfield& c,BNResearchHeightfieldReceipt& r){
        attempted_=true; // Even apply-before-prepare consumes this owner.
        const bool ready=prepared_;prepared_=false; // Consume even a refused apply.
        if(!ready || &r!=receiptOwner_ || !receiptMatches(r) ||
           !metadataMatches(c) ||
           std::memcmp(c.cells,frozenCells_,sizeof(rcCompactCell)*width_*height_) ||
           std::memcmp(c.spans,frozenSpans_,sizeof(rcCompactSpan)*spans_))
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
        const auto status=research_maurer::transform(width_+2,height_+2,radius_,limit_,
            additionalBytes_,b,k);
        r.work_bound=k.bound;r.work_performed=k.work;r.workspace_bytes_declared=k.accountedBytes;
        if(status!=research_maurer::Status::ok)
            return refuse(r,status==research_maurer::Status::work_limit?int(BN_SEED_RADIUS_WORK_LIMIT):
                status==research_maurer::Status::memory_limit?int(BN_ENVELOPE_MEMORY_LIMIT):int(BN_ENVELOPE_KERNEL_REFUSED));
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
