// SOURCE ONLY, newly authored 2026-10-29. No inherited pass/evidence.
#define BN_ENVELOPE_TEST_OBSERVER 1
#include "single_span_heightfield_envelope.h"
#include "RecastAlloc.h"
#include <algorithm>
#include <climits>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <limits>
#include <utility>
#include <vector>
#define REQUIRE(x) do { if (!(x)) { std::fprintf(stderr,"FAIL line %d: %s\n",__LINE__,#x); std::exit(1); } } while (0)
namespace {
unsigned long long oracleChecks=0;
int maskCases=0, refusals=0;
struct Field {
    rcCompactHeightfield* c=rcAllocCompactHeightfield();
    // shape: 0 flat, 1 ramp, 2 ripple, 3 climbable step, 4 rejected-edge step,
    // 5 minimum-clearance ceiling, 6 absent central column.
    explicit Field(int shape=0) {
        REQUIRE(c);c->width=17;c->height=17;c->cs=.025f;c->ch=.025f;
        c->walkableHeight=3;c->walkableClimb=2;
        c->bmax[0]=c->width*c->cs;c->bmax[1]=128*c->ch;c->bmax[2]=c->height*c->cs;
        c->spanCount=17*17-(shape==6?1:0);
        c->cells=(rcCompactCell*)rcAlloc(17*17*sizeof(rcCompactCell),RC_ALLOC_PERM);
        c->spans=(rcCompactSpan*)rcAlloc(c->spanCount*sizeof(rcCompactSpan),RC_ALLOC_PERM);
        c->areas=(unsigned char*)rcAlloc(c->spanCount,RC_ALLOC_PERM);
        REQUIRE(c->cells&&c->spans&&c->areas);
        std::memset(c->cells,0,17*17*sizeof(rcCompactCell));
        std::memset(c->spans,0,c->spanCount*sizeof(rcCompactSpan));
        std::memset(c->areas,RC_WALKABLE_AREA,c->spanCount);
        int i=0;
        for(int z=0;z<17;++z)for(int x=0;x<17;++x){
            auto& cell=c->cells[x+17*z];cell.index=i;
            if(shape==6&&x==8&&z==8)continue;
            cell.count=1;auto& s=c->spans[i++];s.y=10;s.h=100;
            if(shape==1)s.y=10+x;
            if(shape==2)s.y=10+(x%3==1)+(z%3==1);
            if(shape==3&&x>=8)s.y=12;
            if(shape==4&&x>=8)s.y=13;
            if(shape==5&&x==8&&z==8)s.h=3;
            for(int d=0;d<4;++d)rcSetCon(s,d,RC_NOT_CONNECTED);
        }
        for(int z=0;z<17;++z)for(int x=0;x<17;++x){
            const auto cell=c->cells[x+17*z];if(!cell.count)continue;
            auto& s=c->spans[cell.index];
            for(int d=0;d<4;++d){int nx=x+rcGetDirOffsetX(d),nz=z+rcGetDirOffsetY(d);
                if(nx<0||nz<0||nx>=17||nz>=17)continue;
                const auto nc=c->cells[nx+17*nz];if(!nc.count)continue;
                const auto ns=c->spans[nc.index];
                // Released Recast.cpp overlap and climb predicates, not slope flattening.
                int bot=std::max(int(s.y),int(ns.y));
                int top=std::min(int(s.y+s.h),int(ns.y+ns.h));
                if(top-bot>=c->walkableHeight&&std::abs(int(ns.y)-int(s.y))<=c->walkableClimb)
                    rcSetCon(s,d,0);
            }
        }
    }
    ~Field(){rcFreeCompactHeightfield(c);}
    Field(const Field&)=delete;Field& operator=(const Field&)=delete;
};
std::vector<unsigned char> areas(const rcCompactHeightfield& c){return {c.areas,c.areas+c.spanCount};}
std::vector<std::pair<int,int>> seeds(const rcCompactHeightfield& c){
    std::vector<std::pair<int,int>> out;
    for(int z=-1;z<=c.height;++z)for(int x=-1;x<=c.width;++x)
        if(x==-1||z==-1||x==c.width||z==c.height)out.push_back({x,z});
    for(int z=0;z<c.height;++z)for(int x=0;x<c.width;++x){
        auto cell=c.cells[x+z*c.width];if(!cell.count)continue;
        bool seed=c.areas[cell.index]==RC_NULL_AREA;
        for(int d=0;d<4;++d){
            if(rcGetCon(c.spans[cell.index],d)==RC_NOT_CONNECTED){seed=true;continue;}
            int nx=x+rcGetDirOffsetX(d),nz=z+rcGetDirOffsetY(d);
            if(c.areas[c.cells[nx+nz*c.width].index]==RC_NULL_AREA)seed=true;
        }
        if(seed)out.push_back({x,z});
    }return out;
}
void compare(int shape,int radius,bool nullCenter=false){
    Field f(shape);auto& c=*f.c;
    if(nullCenter)c.areas[c.cells[8+8*17].index]=0;
    auto originalSeeds=seeds(c);
    const std::vector<unsigned char> cells((unsigned char*)c.cells,(unsigned char*)(c.cells+17*17));
    const std::vector<unsigned char> spans((unsigned char*)c.spans,(unsigned char*)(c.spans+c.spanCount));
    BNResearchHeightfieldReceipt r={};BNResearchHeightfieldEnvelope e;
    REQUIRE(e.prepare(c,radius,10000000,r));REQUIRE(r.schema==4&&r.algorithm==1&&r.work_unit==1);
    std::vector<unsigned char> packed(19*19,0);
    for(auto seed:originalSeeds)packed[seed.first+1+(seed.second+1)*19]=1;
    REQUIRE(e.paddedCells()==packed.size());REQUIRE(!std::memcmp(e.frozenSeeds(),packed.data(),packed.size()));
    rcContext ctx;REQUIRE(rcErodeWalkableArea(&ctx,radius,c));auto stock=areas(c);
    REQUIRE(e.apply(c,r));int kept=0,stockCount=0;
    for(int z=0;z<17;++z)for(int x=0;x<17;++x){auto cell=c.cells[x+17*z];if(!cell.count)continue;
        bool keep=stock[cell.index]!=0;stockCount+=keep;
        for(auto seed:originalSeeds){REQUIRE(++oracleChecks<=10000000ULL);
            long long dx=x-seed.first,dz=z-seed.second;
            if(dx*dx+dz*dz<static_cast<long long>(radius)*radius)keep=false;
        }
        REQUIRE(c.areas[cell.index]==(keep?stock[cell.index]:0));kept+=keep;
    }
    REQUIRE(r.stock_keep_count==stockCount&&r.exact_keep_count==kept);
    REQUIRE(r.additional_rejected_count==stockCount-kept);
    REQUIRE(r.work_performed<=r.work_bound&&r.work_bound<=r.work_limit);
    REQUIRE(!std::memcmp(c.cells,cells.data(),cells.size()));
    REQUIRE(!std::memcmp(c.spans,spans.data(),spans.size()));
    auto final=areas(c);REQUIRE(!e.apply(c,r));REQUIRE(areas(c)==final);
    ++maskCases;
}
void prepareRefusals(){
    { Field f;auto before=areas(*f.c);
      BNResearchHeightfieldReceipt r={};BNResearchHeightfieldEnvelope e;
      REQUIRE(!e.apply(*f.c,r));REQUIRE(!e.prepare(*f.c,3,10000000,r));
      REQUIRE(areas(*f.c)==before);++refusals;
    }
    for(int k=0;k<13;++k){Field f;auto& c=*f.c;auto before=areas(c);
        if(k==0)c.cells[0].count=2;
        if(k==1)c.cs=0;
        if(k==2)c.ch=std::numeric_limits<float>::quiet_NaN();
        if(k==3)c.bmax[0]=std::numeric_limits<float>::infinity();
        if(k==4)c.bmax[1]=c.bmin[1];
        if(k==5)c.cells[10].index=c.spanCount;
        if(k==6)rcSetCon(c.spans[0],0,0);
        if(k==7)rcSetCon(c.spans[18],0,1);
        if(k==8)rcSetCon(c.spans[18],0,RC_NOT_CONNECTED);
        if(k==9)c.spans[18].y=100; // existing links now violate climb/overlap
        if(k==10)c.spans[18].h=1; // existing links now violate overlap
        if(k==11)c.walkableClimb=-1;
        if(k==12){ // Isolated low ceiling must refuse even with no existing links.
            const int i=8+8*17;c.spans[i].h=2;
            for(int d=0;d<4;++d){
                rcSetCon(c.spans[i],d,RC_NOT_CONNECTED);
                int n=i+rcGetDirOffsetX(d)+17*rcGetDirOffsetY(d);
                rcSetCon(c.spans[n],(d+2)%4,RC_NOT_CONNECTED);
            }
        }
        BNResearchHeightfieldReceipt r={};BNResearchHeightfieldEnvelope e;
        REQUIRE(!e.prepare(c,3,10000000,r));REQUIRE(areas(c)==before);
        REQUIRE(!e.prepare(c,3,10000000,r));++refusals;
    }
    for(auto budget:{0ULL,1ULL,10000001ULL}){Field f;auto before=areas(*f.c);
        BNResearchHeightfieldReceipt r={};BNResearchHeightfieldEnvelope e;
        REQUIRE(!e.prepare(*f.c,3,budget,r));REQUIRE(areas(*f.c)==before);++refusals;
    }
}
void mutationRefusals(){
    for(int k=0;k<20;++k){Field f;auto& c=*f.c;
        BNResearchHeightfieldReceipt r={};BNResearchHeightfieldEnvelope e;
        REQUIRE(e.prepare(c,3,10000000,r));rcContext ctx;REQUIRE(rcErodeWalkableArea(&ctx,3,c));
        auto stock=areas(c);auto* owner=c.areas;auto* cellsOwner=c.cells;auto* spansOwner=c.spans;
        std::vector<unsigned char> otherAreas=stock;
        std::vector<rcCompactCell> otherCells(c.cells,c.cells+17*17);
        std::vector<rcCompactSpan> otherSpans(c.spans,c.spans+c.spanCount);
        if(k==0)c.cs*=2;if(k==1)c.ch*=2;if(k==2)c.bmin[0]+=.025f;
        if(k==3)c.bmax[2]+=.025f;if(k==4)c.walkableHeight++;
        if(k==5)c.walkableClimb++;if(k==6)c.cells[0].index++;
        if(k==7)c.spans[18].y++;if(k==8)c.spans[18].h--;
        if(k==9)rcSetCon(c.spans[18],0,RC_NOT_CONNECTED);
        if(k==10)c.areas=otherAreas.data();if(k==11)c.cells=otherCells.data();
        if(k==12)c.spans=otherSpans.data();
        if(k==13)r.schema++;if(k==14)r.algorithm++;if(k==15)r.work_unit++;
        if(k==16)r.work_limit--;if(k==17)r.radius_cells++;
        if(k==18)r.real_seed_count++;
        BNResearchHeightfieldReceipt copied=r;
        bool result=k==19?e.apply(c,copied):e.apply(c,r);
        REQUIRE(!result);REQUIRE(areas(c)==stock);
        // Restore pointers before field destructor; never free vector storage via rcFree.
        c.areas=owner;c.cells=cellsOwner;c.spans=spansOwner;
        REQUIRE(!e.apply(c,r));REQUIRE(areas(c)==stock);++refusals;
    }
}
}
int main(){
    for(int shape=0;shape<7;++shape)for(int radius:{1,2,3})compare(shape,radius);
    for(int radius:{1,3})compare(2,radius,true);
    prepareRefusals();mutationRefusals();
    std::printf("REBUILT authored masks=%d refusals=%d oracleChecks=%llu PASS\n",maskCases,refusals,oracleChecks);
}
