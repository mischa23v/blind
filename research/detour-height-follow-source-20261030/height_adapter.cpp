// Diagnostic orchestration only. Include the exact historical builder unchanged.
// Header resolved with -I<original blind-tabletop-exclusion-planner-66>.
#include "blind_detour_exclusion.cpp"
#include "DetourCommon.h"
#include <cstdint>
#include <limits>

struct BHResult {
    uint32_t nearestStatus, moveStatus, heightStatus;
    int valid, failureStage, visitedCount;
    uint64_t previousRef, resultRef;
    double horizontalResidual;
    float previous[3], projected[3], actual[3];
    uint64_t visited[4096];
};
struct BHState { BNHandle* owner; dtPolyRef ref; float pos[3]; bool active;
    BHState(BNHandle* h):owner(h),ref(0),active(false) { dtVset(pos,0,0,0); }
};
static void bh_reset(BHResult* r) {
    std::memset(r,0,sizeof(*r));r->horizontalResidual=std::numeric_limits<double>::quiet_NaN();
    for(int i=0;i<3;++i)r->previous[i]=r->projected[i]=r->actual[i]=std::numeric_limits<float>::quiet_NaN();
}
static bool bh_ok(dtStatus s) { return dtStatusSucceed(s) && (s & DT_STATUS_DETAIL_MASK)==0; }
static double bh_distance_xz(const float* a,const float* b) {
    const double x=double(a[0])-b[0],z=double(a[2])-b[2];return std::sqrt(x*x+z*z);
}
extern "C" int bh_abi_version() { return 1; }
extern "C" int bh_result_size() { return int(sizeof(BHResult)); }
extern "C" void bh_destroy(void* state) { delete static_cast<BHState*>(state); }
extern "C" void* bh_begin(void* nav,const float* requested,BHResult* r) {
    if(!r)return 0;bh_reset(r);
    if(!nav||!finite3(requested)){r->failureStage=1;return 0;}
    BNHandle* h=static_cast<BNHandle*>(nav);dtQueryFilter filter;dtPolyRef ref=0;
    const float ext[3]={.2f,.3f,.2f};
    r->nearestStatus=h->query->findNearestPoly(requested,ext,&filter,&ref,r->projected);
    r->resultRef=uint64_t(ref);
    if(!bh_ok(r->nearestStatus)||!ref||!finite3(r->projected)){r->failureStage=2;return 0;}
    r->horizontalResidual=bh_distance_xz(requested,r->projected);
    if(r->horizontalResidual>1e-6){r->failureStage=3;return 0;}
    float height=0;r->heightStatus=h->query->getPolyHeight(ref,r->projected,&height);
    if(!bh_ok(r->heightStatus)||!std::isfinite(height)){r->failureStage=4;return 0;}
    BHState* s=new(std::nothrow) BHState(h);if(!s){r->failureStage=10;return 0;}
    s->ref=ref;dtVcopy(s->pos,r->projected);s->pos[1]=height;s->active=true;
    dtVcopy(r->actual,s->pos);dtVcopy(r->previous,s->pos);r->previousRef=uint64_t(ref);r->valid=1;return s;
}
extern "C" int bh_step(void* state,const float* requested,BHResult* r) {
    if(!r)return 0;bh_reset(r);BHState* s=static_cast<BHState*>(state);
    if(!s||!s->active){r->failureStage=9;return 0;}
    dtVcopy(r->previous,s->pos);r->previousRef=uint64_t(s->ref);
    if(!finite3(requested)){s->active=false;r->failureStage=1;return 0;}
    dtQueryFilter filter;dtPolyRef visited[4096];int count=0;float candidate[3]={std::numeric_limits<float>::quiet_NaN(),std::numeric_limits<float>::quiet_NaN(),std::numeric_limits<float>::quiet_NaN()};
    r->moveStatus=s->owner->query->moveAlongSurface(s->ref,s->pos,requested,&filter,candidate,visited,&count,4096);
    r->visitedCount=count;
    if(count<0||count>4096){s->active=false;r->failureStage=6;return 0;}
    for(int i=0;i<count;++i)r->visited[i]=uint64_t(visited[i]);
    if(finite3(candidate)){dtVcopy(r->projected,candidate);dtVcopy(r->actual,candidate);}
    if(!bh_ok(r->moveStatus)||!finite3(candidate)){s->active=false;r->failureStage=5;return 0;}
    if(count==0||!visited[count-1]){s->active=false;r->failureStage=6;return 0;}
    r->resultRef=uint64_t(visited[count-1]);r->horizontalResidual=bh_distance_xz(candidate,requested);
    if(r->horizontalResidual>1e-6){s->active=false;r->failureStage=7;return 0;}
    float height=0;r->heightStatus=s->owner->query->getPolyHeight(visited[count-1],candidate,&height);
    if(!bh_ok(r->heightStatus)||!std::isfinite(height)){s->active=false;r->failureStage=8;return 0;}
    candidate[1]=height;dtVcopy(r->actual,candidate);
    // Only local polygon-state traversal is updated; no user/body is moved.
    s->ref=visited[count-1];dtVcopy(s->pos,candidate);r->valid=1;return 1;
}
