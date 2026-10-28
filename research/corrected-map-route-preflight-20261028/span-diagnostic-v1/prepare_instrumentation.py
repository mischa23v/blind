from pathlib import Path
import hashlib,json,shutil
H=Path(__file__).resolve().parent;P=H.parent/'occupancy-prototype-v3';s=(P/'occupancy_adapter.cpp').read_text()
extra='''
struct BNDebugSpan { int x,z,smin,smax,initialTag,afterLedgeArea,afterHeadArea; };
struct BNStageStats { int beforeFilters,afterLedge,afterHead,compact,eroded,distance,regions,polygons,vertices; float ox,oy,oz,cs,ch; };
static thread_local std::vector<BNDebugSpan> debug_spans;
static thread_local BNStageStats stage_stats;
extern "C" int bn_debug_span_count(){return (int)debug_spans.size();}
extern "C" int bn_debug_spans(BNDebugSpan* out,int cap){if(!out||cap<(int)debug_spans.size())return 0;std::memcpy(out,debug_spans.data(),debug_spans.size()*sizeof(BNDebugSpan));return (int)debug_spans.size();}
extern "C" void bn_stage_stats(BNStageStats* out){if(out)*out=stage_stats;}
static int count_walkable(const rcHeightfield& h){int n=0;for(int i=0;i<h.width*h.height;i++)for(rcSpan*p=h.spans[i];p;p=p->next)n+=p->area!=RC_NULL_AREA;return n;}
static int count_compact(const rcCompactHeightfield& h){int n=0;for(int i=0;i<h.spanCount;i++)n+=h.areas[i]!=RC_NULL_AREA;return n;}
static void snapshot_area(const rcHeightfield& h,bool head){size_t n=0;for(int i=0;i<h.width*h.height;i++)for(rcSpan*p=h.spans[i];p;p=p->next){if(head)debug_spans[n].afterHeadArea=p->area;else debug_spans[n].afterLedgeArea=p->area;n++;}}
'''
s=s.replace('extern "C" void* bn_build_occupancy',extra+'\nextern "C" void* bn_build_occupancy')
s=s.replace('error_message[0]=0;std::memset(&occ_stats,0,sizeof(occ_stats));','error_message[0]=0;std::memset(&occ_stats,0,sizeof(occ_stats));debug_spans.clear();std::memset(&stage_stats,0,sizeof(stage_stats));')
s=s.replace('occ_stats.width=config.width;occ_stats.depth=config.height;','occ_stats.width=config.width;occ_stats.depth=config.height;stage_stats.ox=config.bmin[0];stage_stats.oy=config.bmin[1];stage_stats.oz=config.bmin[2];stage_stats.cs=config.cs;stage_stats.ch=config.ch;')
s=s.replace('if(p->area==1)occ_stats.provisionalSpans++;else occ_stats.obstacleSpans++;','debug_spans.push_back({i%config.width,i/config.width,(int)p->smin,(int)p->smax,(int)p->area,0,0});\n  if(p->area==1)occ_stats.provisionalSpans++;else occ_stats.obstacleSpans++;')
s=s.replace('    // No low-hanging-obstacle promotion:', '    stage_stats.beforeFilters=count_walkable(*b.heightfield);\n    // No low-hanging-obstacle promotion:')
x='rcFilterLedgeSpans(&context, config.walkableHeight, config.walkableClimb, *b.heightfield);';s=s.replace(x,x+'\n    stage_stats.afterLedge=count_walkable(*b.heightfield);snapshot_area(*b.heightfield,false);')
x='rcFilterWalkableLowHeightSpans(&context, config.walkableHeight, *b.heightfield);';s=s.replace(x,x+'\n    stage_stats.afterHead=count_walkable(*b.heightfield);snapshot_area(*b.heightfield,true);')
a=s.index('    if (!rcErodeWalkableArea');b=s.index('    if (b.mesh->npolys < 1)',a)
s=s[:a]+'''    stage_stats.compact=count_compact(*b.compact);
    if(!rcErodeWalkableArea(&context,config.walkableRadius,*b.compact)){fail("Recast erosion");return 0;}stage_stats.eroded=count_compact(*b.compact);
    if(!rcBuildDistanceField(&context,*b.compact)){fail("Recast distance");return 0;}stage_stats.distance=count_compact(*b.compact);
    if(!rcBuildRegions(&context,*b.compact,0,config.minRegionArea,config.mergeRegionArea)){fail("Recast regions");return 0;}stage_stats.regions=count_compact(*b.compact);
    if(!rcBuildContours(&context,*b.compact,config.maxSimplificationError,config.maxEdgeLen,*b.contours) || !rcBuildPolyMesh(&context,*b.contours,config.maxVertsPerPoly,*b.mesh) || !rcBuildPolyMeshDetail(&context,*b.mesh,*b.compact,config.detailSampleDist,config.detailSampleMaxError,*b.detail)){fail("Recast mesh");return 0;}
    stage_stats.polygons=b.mesh->npolys;stage_stats.vertices=b.mesh->nverts;
'''+s[b:]
(H/'occupancy_adapter.cpp').write_text(s)
for n in ['occupancy_engine.py','test_occupancy.py','run_prototype.py']:shutil.copyfile(P/n,H/n)
(H/'INSTRUMENTATION_RECEIPT.json').write_text(json.dumps({'sourceSHA256':hashlib.sha256((P/'occupancy_adapter.cpp').read_bytes()).hexdigest(),'changes':'Read-only per-stage counts and merged-span snapshots. Existing combined native stage condition expanded into same ordered calls to capture counts; no parameter/filter/policy change.','unchangedBindingSHA256':hashlib.sha256((P/'occupancy_engine.py').read_bytes()).hexdigest(),'physicalAuthority':False},indent=2)+'\n')
