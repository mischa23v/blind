// Local adapter over unmodified Recast/Detour at the pin in UPSTREAM_MANIFEST.json.
// NOT a replacement SLAM/search algorithm or a validated human controller.
#include "include/blind_detour.h"
#include "Recast.h"
#include "DetourNavMesh.h"
#include "DetourNavMeshBuilder.h"
#include "DetourNavMeshQuery.h"
#include "DetourObstacleAvoidance.h"
#include <cmath>
#include <cstdio>
#include <cstring>
#include <new>
#include <vector>

static thread_local char error_message[256] = "";
static void fail(const char* s) { std::snprintf(error_message, sizeof(error_message), "%s", s); }
static bool finite3(const float* p) { return p && std::isfinite(p[0]) && std::isfinite(p[1]) && std::isfinite(p[2]); }
struct BNHandle {
    dtNavMesh* mesh;
    dtNavMeshQuery* query;
    int excludedSpanCount;
    BNHandle(): mesh(0), query(0), excludedSpanCount(0) {}
    ~BNHandle() { if (query) dtFreeNavMeshQuery(query); if (mesh) dtFreeNavMesh(mesh); }
};
struct BuildData {
    rcHeightfield* heightfield;
    rcCompactHeightfield* compact;
    rcContourSet* contours;
    rcPolyMesh* mesh;
    rcPolyMeshDetail* detail;
    BuildData(): heightfield(0), compact(0), contours(0), mesh(0), detail(0) {}
    ~BuildData() {
        if (heightfield) rcFreeHeightField(heightfield);
        if (compact) rcFreeCompactHeightfield(compact);
        if (contours) rcFreeContourSet(contours);
        if (mesh) rcFreePolyMesh(mesh);
        if (detail) rcFreePolyMeshDetail(detail);
    }
};
extern "C" const char* bn_last_error() { return error_message; }
extern "C" void bn_destroy(void* handle) { delete static_cast<BNHandle*>(handle); }
static void* build_impl(const float* v, int nv, const int* t, int nt, const BNConfig* c, const float* exclusion, int exclusionCount, float observedMinY, float observedMaxY, const unsigned char* triangleSupport, bool classifiedFloorOnly) {
    error_message[0] = 0;
    if (!v || !t || !c || nv < 3 || nv > 250000 || nt < 1 || nt > 500000) { fail("invalid/count-limited mesh input"); return 0; }
    if (classifiedFloorOnly && !triangleSupport) { fail("missing triangle support"); return 0; }
    if (classifiedFloorOnly) for (int i=0; i<nt; ++i) if (triangleSupport[i]>1) { fail("invalid triangle support"); return 0; }
    if (!std::isfinite(c->radius) || c->radius < .1f || c->radius > 2.f ||
        !std::isfinite(c->height) || c->height < .5f || c->height > 3.f ||
        !std::isfinite(c->cell_size) || c->cell_size < .025f || c->cell_size > .5f ||
        !std::isfinite(c->cell_height) || c->cell_height < .01f || c->cell_height > .2f ||
        !std::isfinite(c->max_climb) || c->max_climb < 0.f || c->max_climb > .09f ||
        !std::isfinite(c->max_slope) || c->max_slope < 0.f || c->max_slope > 15.f ||
        c->max_cells < 1 || c->max_cells > 250000 || c->max_nodes < 16 || c->max_nodes > 65535) {
        fail("invalid bounded configuration"); return 0;
    }
    if (exclusionCount < 0 || exclusionCount > 64 || (exclusionCount && (exclusionCount < 3 || !exclusion || !std::isfinite(observedMinY) || !std::isfinite(observedMaxY) || observedMinY > observedMaxY))) { fail("invalid exclusion count or observed height range"); return 0; }
    if (exclusionCount) {
        double orientation = 0.;
        for (int i=0; i<exclusionCount; ++i) {
            const float* a=exclusion+3*i; const float* b=exclusion+3*((i+1)%exclusionCount); const float* d=exclusion+3*((i+2)%exclusionCount);
            if (!finite3(a) || std::fabs(a[0])>10000.f || std::fabs(a[2])>10000.f) { fail("nonfinite/out-of-range exclusion vertex"); return 0; }
            double cross=(double(b[0])-a[0])*(double(d[2])-b[2])-(double(b[2])-a[2])*(double(d[0])-b[0]);
            if (std::fabs(cross)>1e-12) { if (orientation && orientation*cross<0.) { fail("nonconvex exclusion"); return 0; } orientation=cross; }
        }
        if (!orientation) { fail("degenerate exclusion"); return 0; }
        for (int i=0; i<exclusionCount; ++i) {
            const float* a=exclusion+3*i; const float* b=exclusion+3*((i+1)%exclusionCount);
            for (int j=i+1; j<exclusionCount; ++j) {
                const float* q=exclusion+3*j;
                double qx=double(q[0])-a[0], qz=double(q[2])-a[2];
                if (qx*qx+qz*qz<1e-16) { fail("duplicate exclusion vertex"); return 0; }
            }
            double dx=double(b[0])-a[0], dz=double(b[2])-a[2];
            if (dx*dx+dz*dz<1e-16) { fail("duplicate exclusion vertex"); return 0; }
            for (int j=0; j<exclusionCount; ++j) {
                const float* q=exclusion+3*j;
                double cross=dx*(double(q[2])-a[2])-dz*(double(q[0])-a[0]);
                if ((orientation>0 && cross < -1e-10) || (orientation<0 && cross > 1e-10)) { fail("nonconvex or self-intersecting exclusion"); return 0; }
            }
        }
    }
    for (int i=0; i<nv*3; ++i) if (!std::isfinite(v[i]) || std::fabs(v[i]) > 10000.f) { fail("invalid vertex"); return 0; }
    for (int i=0; i<nt*3; ++i) if (t[i] < 0 || t[i] >= nv) { fail("invalid triangle index"); return 0; }
    rcContext context(false);
    rcConfig config; std::memset(&config, 0, sizeof(config));
    config.cs = c->cell_size; config.ch = c->cell_height;
    config.walkableSlopeAngle = c->max_slope;
    config.walkableHeight = (int)std::ceil(c->height/config.ch);
    config.walkableClimb = (int)std::floor(c->max_climb/config.ch);
    config.walkableRadius = (int)std::ceil(c->radius/config.cs);
    config.maxEdgeLen = 0; config.maxSimplificationError = .5f;
    config.minRegionArea = 0; config.mergeRegionArea = 0; config.maxVertsPerPoly = 6;
    config.detailSampleDist = config.cs*6.f; config.detailSampleMaxError = config.ch;
    rcCalcBounds(v, nv, config.bmin, config.bmax);
    if (config.bmax[0]-config.bmin[0] > 200.f || config.bmax[2]-config.bmin[2] > 200.f ||
        config.bmax[1]-config.bmin[1] > 20.f) { fail("mesh extent limit"); return 0; }
    config.bmin[1] -= config.ch;
    config.bmax[1] += c->height + config.ch;
    rcCalcGridSize(config.bmin, config.bmax, config.cs, &config.width, &config.height);
    if (config.width < 1 || config.height < 1 || (long long)config.width*config.height > c->max_cells) { fail("grid cell cap"); return 0; }
    BuildData b;
    b.heightfield=rcAllocHeightfield(); b.compact=rcAllocCompactHeightfield();
    b.contours=rcAllocContourSet(); b.mesh=rcAllocPolyMesh(); b.detail=rcAllocPolyMeshDetail();
    if (!b.heightfield || !b.compact || !b.contours || !b.mesh || !b.detail) { fail("build allocation"); return 0; }
    if (!rcCreateHeightfield(&context, *b.heightfield, config.width, config.height, config.bmin, config.bmax, config.cs, config.ch)) { fail("heightfield"); return 0; }
    std::vector<unsigned char> areas(nt, RC_NULL_AREA);
    if (classifiedFloorOnly) {
        // Recast addSpan merges overlapping area IDs with max(). Its maximum
        // height is updated BEFORE that comparison, so ordinary floor=63 and
        // obstacle=0 can promote a floor-touching obstacle top. Use temporary
        // priorities floor=1 / obstacle=2, then map only retained floor to 63.
        // These are raster provenance tags, not new navigation/search logic.
        for (int i=0; i<nt; ++i) if (triangleSupport[i]==1) areas[i]=1;
        // Upstream only clears steep/downward floor triangles. It never promotes
        // furniture, walls or unclassified geometry to support in this mode.
        rcClearUnwalkableTriangles(&context, config.walkableSlopeAngle, v, nv, t, nt, areas.data());
        for (int i=0; i<nt; ++i) if (triangleSupport[i]==0) areas[i]=2;
    } else {
        // Preserve the original unclassified diagnostic build byte-for-byte path.
        rcMarkWalkableTriangles(&context, config.walkableSlopeAngle, v, nv, t, nt, areas.data());
    }
    if (!rcRasterizeTriangles(&context, v, nv, t, areas.data(), nt, *b.heightfield, config.walkableClimb)) { fail("rasterization"); return 0; }
    if (classifiedFloorOnly) {
        for (int i=0; i<config.width*config.height; ++i) {
            for (rcSpan* span=b.heightfield->spans[i]; span; span=span->next) {
                span->area=span->area==1 ? RC_WALKABLE_AREA : RC_NULL_AREA;
            }
        }
    }
    // No low-hanging-obstacle promotion: an observed obstacle is not made floor.
    rcFilterLedgeSpans(&context, config.walkableHeight, config.walkableClimb, *b.heightfield);
    rcFilterWalkableLowHeightSpans(&context, config.walkableHeight, *b.heightfield);
    if (!rcBuildCompactHeightfield(&context, config.walkableHeight, config.walkableClimb, *b.heightfield, *b.compact)) { fail("compact heightfield"); return 0; }
    int excludedSpanCount=0;
    if (exclusionCount) {
        int before=0, after=0;
        for (int i=0; i<b.compact->spanCount; ++i) before += b.compact->areas[i]!=RC_NULL_AREA;
        // A candidate body's vertical interval [foot, foot+nativeHeight]
        // intersects the observed tabletop height hypothesis in this interval.
        // Mark raw source exclusion BEFORE radius erosion: no double inflation.
        rcMarkConvexPolyArea(&context, exclusion, exclusionCount, observedMinY-c->height, observedMaxY, RC_NULL_AREA, *b.compact);
        for (int i=0; i<b.compact->spanCount; ++i) after += b.compact->areas[i]!=RC_NULL_AREA;
        excludedSpanCount=before-after;
    }
    if (!rcErodeWalkableArea(&context, config.walkableRadius, *b.compact) ||
        !rcBuildDistanceField(&context, *b.compact) ||
        !rcBuildRegions(&context, *b.compact, 0, config.minRegionArea, config.mergeRegionArea) ||
        !rcBuildContours(&context, *b.compact, config.maxSimplificationError, config.maxEdgeLen, *b.contours) ||
        !rcBuildPolyMesh(&context, *b.contours, config.maxVertsPerPoly, *b.mesh) ||
        !rcBuildPolyMeshDetail(&context, *b.mesh, *b.compact, config.detailSampleDist, config.detailSampleMaxError, *b.detail)) {
        fail("Recast build stage"); return 0;
    }
    if (b.mesh->npolys < 1) { fail("no supported walkable polygons"); return 0; }
    for (int i=0; i<b.mesh->npolys; ++i) { b.mesh->flags[i]=1; if (b.mesh->areas[i]==RC_WALKABLE_AREA) b.mesh->areas[i]=0; }
    dtNavMeshCreateParams params; std::memset(&params, 0, sizeof(params));
    params.verts=b.mesh->verts; params.vertCount=b.mesh->nverts;
    params.polys=b.mesh->polys; params.polyAreas=b.mesh->areas; params.polyFlags=b.mesh->flags;
    params.polyCount=b.mesh->npolys; params.nvp=b.mesh->nvp;
    params.detailMeshes=b.detail->meshes; params.detailVerts=b.detail->verts; params.detailVertsCount=b.detail->nverts;
    params.detailTris=b.detail->tris; params.detailTriCount=b.detail->ntris;
    params.walkableHeight=c->height; params.walkableRadius=c->radius; params.walkableClimb=c->max_climb;
    std::memcpy(params.bmin,b.mesh->bmin,sizeof(params.bmin)); std::memcpy(params.bmax,b.mesh->bmax,sizeof(params.bmax));
    params.cs=config.cs; params.ch=config.ch; params.buildBvTree=true;
    unsigned char* data=0; int bytes=0;
    if (!dtCreateNavMeshData(&params,&data,&bytes)) { fail("Detour mesh creation"); return 0; }
    BNHandle* h=new(std::nothrow) BNHandle();
    if (!h) { dtFree(data); fail("handle allocation"); return 0; }
    h->mesh=dtAllocNavMesh(); h->query=dtAllocNavMeshQuery();
    if (!h->mesh || !h->query) { dtFree(data); delete h; fail("Detour allocation"); return 0; }
    if (dtStatusFailed(h->mesh->init(data,bytes,DT_TILE_FREE_DATA))) { dtFree(data); delete h; fail("Detour mesh init"); return 0; }
    if (dtStatusFailed(h->query->init(h->mesh,c->max_nodes))) { delete h; fail("Detour query init"); return 0; }
    h->excludedSpanCount=excludedSpanCount;
    return h;
}
extern "C" int bn_path(void* handle,const float* start,const float* goal,const float* ext,float* points,int cap,
                       float* projected_start,float* projected_goal,unsigned int* status,int* complete) {
    error_message[0]=0;
    if (status) *status=0;
    if (complete) *complete=0;
    if (!handle || !finite3(start) || !finite3(goal) || !finite3(ext) || !points || !projected_start || !projected_goal || !status || !complete ||
        cap<2 || cap>4096 || ext[0]<=0 || ext[1]<=0 || ext[2]<=0 || ext[0]>3 || ext[1]>3 || ext[2]>3) { fail("invalid query"); return -1; }
    BNHandle* h=static_cast<BNHandle*>(handle); dtQueryFilter filter; filter.setIncludeFlags(1); filter.setExcludeFlags(0);
    dtPolyRef a=0,b=0;
    dtStatus s1=h->query->findNearestPoly(start,ext,&filter,&a,projected_start);
    dtStatus s2=h->query->findNearestPoly(goal,ext,&filter,&b,projected_goal);
    *status=s1|s2;
    if (dtStatusFailed(s1)||dtStatusFailed(s2)||!a||!b) { fail("no start or goal polygon within explicit association bounds"); return -1; }
    std::vector<dtPolyRef> corridor(4096); int nc=0;
    dtStatus s3=h->query->findPath(a,b,projected_start,projected_goal,&filter,corridor.data(),&nc,(int)corridor.size()); *status|=s3;
    if (dtStatusFailed(s3)||nc<1) { fail("no route corridor"); return -1; }
    float end[3]; std::memcpy(end,projected_goal,sizeof(end));
    if (corridor[nc-1]!=b && dtStatusFailed(h->query->closestPointOnPoly(corridor[nc-1],projected_goal,end,0))) { fail("partial endpoint query"); return -1; }
    std::vector<unsigned char> flags(cap); std::vector<dtPolyRef> refs(cap); int count=0;
    dtStatus s4=h->query->findStraightPath(projected_start,end,corridor.data(),nc,points,flags.data(),refs.data(),&count,cap); *status|=s4;
    if (dtStatusFailed(s4)) { fail("straight path query"); return -1; }
    *complete=(corridor[nc-1]==b && !dtStatusDetail(*status,DT_PARTIAL_RESULT|DT_BUFFER_TOO_SMALL|DT_OUT_OF_NODES));
    return count;
}
extern "C" int bn_velocity(const float* pos,float radius,float vmax,const float* vel,const float* desired,float horizon,
                           const float* circles,int nc,const float* segments,int ns,float* output) {
    error_message[0]=0;
    if (!finite3(pos)||!finite3(vel)||!finite3(desired)||!output||!std::isfinite(radius)||radius<.1f||radius>2||!std::isfinite(vmax)||vmax<=0||vmax>3||
        !std::isfinite(horizon)||horizon<=0||horizon>10||nc<0||nc>64||ns<0||ns>128||(nc&&!circles)||(ns&&!segments)) { fail("invalid velocity request"); return -1; }
    for (int i=0;i<nc*7;i++) if (!std::isfinite(circles[i])) {fail("nonfinite circle");return -1;}
    for (int i=0;i<ns*6;i++) if (!std::isfinite(segments[i])) {fail("nonfinite segment");return -1;}
    dtObstacleAvoidanceQuery query; if (!query.init(64,128)) {fail("avoidance allocation");return -1;}
    for (int i=0;i<nc;i++) {const float* c=circles+i*7;if(c[3]<=0||c[3]>5){fail("circle radius");return -1;}query.addCircle(c,c[3],c+4,c+4);}
    for (int i=0;i<ns;i++) query.addSegment(segments+i*6,segments+i*6+3);
    dtObstacleAvoidanceParams p; std::memset(&p,0,sizeof(p));
    p.velBias=.4f;p.weightDesVel=2;p.weightCurVel=.75f;p.weightSide=.75f;p.weightToi=2.5f;p.horizTime=horizon;
    p.gridSize=33;p.adaptiveDivs=7;p.adaptiveRings=2;p.adaptiveDepth=5;
    return query.sampleVelocityAdaptive(pos,radius,vmax,vel,desired,output,&p);
}

extern "C" void* bn_build_excluded(const float* v, int nv, const int* t, int nt, const BNConfig* c, const float* exclusion, int exclusionCount, float observedMinY, float observedMaxY) {
    return build_impl(v,nv,t,nt,c,exclusion,exclusionCount,observedMinY,observedMaxY,0,false);
}
extern "C" void* bn_build_classified(const float* v, int nv, const int* t, int nt, const BNConfig* c, const unsigned char* triangleSupport) {
    return build_impl(v,nv,t,nt,c,0,0,0.f,0.f,triangleSupport,true);
}
extern "C" void* bn_build(const float* v, int nv, const int* t, int nt, const BNConfig* c) {
    return bn_build_excluded(v,nv,t,nt,c,0,0,0.f,0.f);
}
extern "C" int bn_excluded_span_count(void* handle) {
    return handle ? static_cast<BNHandle*>(handle)->excludedSpanCount : -1;
}
