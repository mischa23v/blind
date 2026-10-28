// ISOLATED GEOMETRY-ONLY DIAGNOSTIC. Ground labels are support hypotheses.
// Original wrapper and released planner are included unchanged. No physical authority.
#include "../native/clearance_adapter.cpp"
#include <cstdint>
#include <limits>
struct BNOccupancyLeaf { float x,y,z,size,probability; int32_t type,node,occupied; };
static_assert(sizeof(BNOccupancyLeaf)==32,"ledger ABI");
struct BNOccupancyStats { int rows,occupied,free,ground,other,width,depth,insertions,provisionalSpans,obstacleSpans; };
static thread_local BNOccupancyStats occ_stats;
extern "C" void bn_occupancy_stats(BNOccupancyStats* out) { if(out)*out=occ_stats; }
static bool leaf_valid(const BNOccupancyLeaf& a) {
 return finite3(&a.x) && std::fabs(a.x)<=10000 && std::fabs(a.y)<=10000 && std::fabs(a.z)<=10000 &&
 std::isfinite(a.size) && a.size>=.01f && a.size<=.5f && std::isfinite(a.probability) && a.probability>=0 && a.probability<=1 &&
 (a.occupied==0 || a.occupied==1) && bool(a.occupied)==(a.probability>=.5f) &&
 (a.type==-1 || a.type==0 || a.type==1 || a.type==100);
}
static void leaf_bounds(const BNOccupancyLeaf& a,double* lo,double* hi) {
 const double center[3]={a.x,a.z,-double(a.y)}; // P=(X,Y,Z) -> Q=(X,Z,-Y), det +1.
 for(int k=0;k<3;k++){lo[k]=center[k]-double(a.size)/2;hi[k]=center[k]+double(a.size)/2;}
}
extern "C" int bn_occupancy_leaf_bounds(const BNOccupancyLeaf* a,double* lo,double* hi) {
 if(!a || !lo || !hi || !leaf_valid(*a))return 0;leaf_bounds(*a,lo,hi);return 1;
}
extern "C" void* bn_build_occupancy(const BNOccupancyLeaf* rows,int count,const BNConfig* c) {
 error_message[0]=0;std::memset(&occ_stats,0,sizeof(occ_stats));
 if(!rows || !c || count<1 || count>2500000){fail("invalid/count-limited occupancy input");return 0;}
    if (!std::isfinite(c->radius) || c->radius < .1f || c->radius > 2.f ||
        !std::isfinite(c->height) || c->height < .5f || c->height > 3.f ||
        !std::isfinite(c->cell_size) || c->cell_size < .025f || c->cell_size > .5f ||
        !std::isfinite(c->cell_height) || c->cell_height < .01f || c->cell_height > .2f ||
        !std::isfinite(c->max_climb) || c->max_climb < 0.f || c->max_climb > .09f ||
        !std::isfinite(c->max_slope) || c->max_slope < 0.f || c->max_slope > 15.f ||
        c->max_cells < 1 || c->max_cells > 250000 || c->max_nodes < 16 || c->max_nodes > 65535) {
        fail("invalid bounded configuration"); return 0;
    }

 double lo[3]={1e30,1e30,1e30},hi[3]={-1e30,-1e30,-1e30};occ_stats.rows=count;
 for(int i=0;i<count;i++){
  const BNOccupancyLeaf& a=rows[i];if(!leaf_valid(a)){fail("invalid occupancy leaf");return 0;}
  if(!a.occupied){occ_stats.free++;continue;}occ_stats.occupied++;
  if(a.type==1)occ_stats.ground++;else occ_stats.other++;
  double l[3],h[3];leaf_bounds(a,l,h);for(int k=0;k<3;k++){lo[k]=std::fmin(lo[k],l[k]);hi[k]=std::fmax(hi[k],h[k]);}
 }
 if(!occ_stats.occupied){fail("no occupied geometry");return 0;}
 if(hi[0]-lo[0]>200 || hi[2]-lo[2]>200 || hi[1]-lo[1]>20){fail("occupancy extent limit");return 0;}
 rcContext context(false);rcConfig config;std::memset(&config,0,sizeof(config));
    config.cs = c->cell_size; config.ch = c->cell_height;
    config.walkableSlopeAngle = c->max_slope;
    config.walkableHeight = (int)std::ceil(c->height/config.ch);
    config.walkableClimb = (int)std::floor(c->max_climb/config.ch);
    config.walkableRadius = (int)std::ceil(c->radius/config.cs);
    config.maxEdgeLen = 0; config.maxSimplificationError = .5f;
    config.minRegionArea = 0; config.mergeRegionArea = 0; config.maxVertsPerPoly = 6;
    config.detailSampleDist = config.cs*6.f; config.detailSampleMaxError = config.ch;

 // Outward Float32 rounding: never shrink a supplied occupied box.
 for(int k=0;k<3;k++){config.bmin[k]=std::nextafter(float(lo[k]),-std::numeric_limits<float>::infinity());config.bmax[k]=std::nextafter(float(hi[k]),std::numeric_limits<float>::infinity());}
 config.bmin[1]-=config.ch;config.bmax[1]+=c->height+config.ch;
 // rcCalcGridSize rounds to nearest. ceil preserves the last partial occupied cell.
 config.width=int(std::ceil((double(config.bmax[0])-config.bmin[0])/config.cs));
 config.height=int(std::ceil((double(config.bmax[2])-config.bmin[2])/config.cs));
 if(config.width<1 || config.height<1 || (long long)config.width*config.height>c->max_cells){fail("grid cell cap");return 0;}
 if((double(config.bmax[1])-config.bmin[1])/config.ch>=RC_SPAN_MAX_HEIGHT){fail("span height cap");return 0;}
 occ_stats.width=config.width;occ_stats.depth=config.height;
    BuildData b;
    b.heightfield=rcAllocHeightfield(); b.compact=rcAllocCompactHeightfield();
    b.contours=rcAllocContourSet(); b.mesh=rcAllocPolyMesh(); b.detail=rcAllocPolyMeshDetail();
    if (!b.heightfield || !b.compact || !b.contours || !b.mesh || !b.detail) { fail("build allocation"); return 0; }
    if (!rcCreateHeightfield(&context, *b.heightfield, config.width, config.height, config.bmin, config.bmax, config.cs, config.ch)) { fail("heightfield"); return 0; }

 for(int i=0;i<count;i++){
  const BNOccupancyLeaf& a=rows[i];if(!a.occupied)continue;double l[3],h[3];leaf_bounds(a,l,h);
  const int x0=int(std::floor((l[0]-config.bmin[0])/config.cs));
  const int x1=int(std::ceil((h[0]-config.bmin[0])/config.cs))-1;
  const int z0=int(std::floor((l[2]-config.bmin[2])/config.cs));
  const int z1=int(std::ceil((h[2]-config.bmin[2])/config.cs))-1;
  const int y0=int(std::floor((l[1]-config.bmin[1])/config.ch));
  const int y1=int(std::ceil((h[1]-config.bmin[1])/config.ch));
  if(x0<0 || z0<0 || x1>=config.width || z1>=config.height || x1<x0 || z1<z0 || y0<0 || y1<=y0 || y1>RC_SPAN_MAX_HEIGHT){fail("unrepresentable leaf bounds");return 0;}
  for(int z=z0;z<=z1;z++)for(int x=x0;x<=x1;x++){
   if(++occ_stats.insertions>10000000){fail("span insertion cap");return 0;}
   // Official addSpan merges touching/overlapping intervals. Full-height flag
   // threshold preserves maximum obstacle priority regardless of insertion order.
   // It does NOT close separated vertical intervals or make unknown space free.
   if(!rcAddSpan(&context,*b.heightfield,x,z,(unsigned short)y0,(unsigned short)y1,a.type==1?1:2,RC_SPAN_MAX_HEIGHT)){fail("occupancy span allocation");return 0;}
  }
 }
 for(int i=0;i<config.width*config.height;i++)for(rcSpan* p=b.heightfield->spans[i];p;p=p->next){
  if(p->area==1)occ_stats.provisionalSpans++;else occ_stats.obstacleSpans++;
  p->area=p->area==1?RC_WALKABLE_AREA:RC_NULL_AREA;
 }
    // No low-hanging-obstacle promotion: an observed obstacle is not made floor.
    rcFilterLedgeSpans(&context, config.walkableHeight, config.walkableClimb, *b.heightfield);
    rcFilterWalkableLowHeightSpans(&context, config.walkableHeight, *b.heightfield);
    if (!rcBuildCompactHeightfield(&context, config.walkableHeight, config.walkableClimb, *b.heightfield, *b.compact)) { fail("compact heightfield"); return 0; }
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
    h->excludedSpanCount=0;
    return h;
}
