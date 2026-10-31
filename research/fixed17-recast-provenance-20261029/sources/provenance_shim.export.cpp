// Private diagnostic shim. No planner, reference geometry, route or repaired map API.
#include "observer.h"
#include "private_fixture_config.h" // NOT DISTRIBUTED: frozen bounds/cells belong to private data
// EXPORT VARIANT, NOT THE EXECUTED SOURCE. Original hash is in SOURCE_MAP.json.
#include <vector>
#include <cstring>
#include <cmath>
#include <algorithm>
namespace {
const int W=fixture::width,H=fixture::height, MAX_SPANS=200000, MAX_TRI=2000;
// fixture::cells must contain the private frozen 17 native cells in original order.
const auto& CELLS=fixture::cells;
bool create(rcContext& c,rcHeightfield& h){
 float lo[3],hi[3];std::memcpy(lo,fixture::inputMin,sizeof(lo));std::memcpy(hi,fixture::inputMax,sizeof(hi));
 lo[1]-=.02f; hi[1]+=1.2f+.02f;
 return rcCreateHeightfield(&c,h,W,H,lo,hi,.04f,.02f);
}
bool restore(rcContext& c,rcHeightfield& h,const int* rows,int n){
 if(!create(c,h))return false;
 for(int i=0;i<n;++i){const int* r=rows+i*9;
  if(r[0]<0||r[0]>=W||r[1]<0||r[1]>=H||r[2]<0||r[3]>RC_SPAN_MAX_HEIGHT||r[2]>=r[3]||r[6]<0||r[6]>63)return false;
  if(!rcAddSpan(&c,h,r[0],r[1],(unsigned short)r[2],(unsigned short)r[3],(unsigned char)r[6],2))return false;
 }
 // Require reconstruction of all null/non-null saved layers, not merely walkable tops.
 int i=0;for(int z=0;z<H;++z)for(int x=0;x<W;++x)for(rcSpan* s=h.spans[x+z*W];s;s=s->next){
  if(i>=n)return false;const int* r=rows+9*i++;
  if(r[0]!=x||r[1]!=z||r[2]!=s->smin||r[3]!=s->smax||r[6]!=s->area)return false;
 }return i==n;
}
}
// Output columns: x,z,y,h,areaBefore,areaAfter,distance,seedIndex, four absolute links.
// Output events snapshot ancestry at the strict improvement, not mutable final parents.
extern "C" int provenance_compact(const int* rows,int n,int* output,int outputRows,
                                  ProvenanceEvent* events,int eventCapacity,int* eventCount){
 try {
  if(!rows||!output||!events||!eventCount||n<1||n>MAX_SPANS||outputRows<n||eventCapacity<9*n)return -1;
  rcContext c(false);rcHeightfield h1,h2;rcCompactHeightfield a,b;
  if(!restore(c,h1,rows,n)||!restore(c,h2,rows,n))return -2;
  if(!rcBuildCompactHeightfield(&c,61,2,h1,a)||!rcBuildCompactHeightfield(&c,61,2,h2,b)||a.spanCount!=b.spanCount)return -3;
  const int ns=a.spanCount;
  std::vector<int> seed(ns,-1),event(ns,-1);std::vector<unsigned char> dist(ns),before(a.areas,a.areas+ns);
  ProvenanceTrace trace={seed.data(),event.data(),dist.data(),events,0,eventCapacity,false};
  if(!provenanceErode(&c,6,a,trace)||!rcErodeWalkableArea(&c,6,b)||trace.overflow)return -4;
  if(std::memcmp(a.areas,b.areas,ns)!=0)return -5;
  int raw=0;
  for(int z=0;z<H;++z)for(int x=0;x<W;++x){const rcCompactCell& cell=a.cells[x+z*W];
   for(unsigned int i=cell.index;i<cell.index+cell.count;++i){
    while(raw<n && !rows[raw*9+6])++raw;
    if(raw>=n||rows[raw*9]!=x||rows[raw*9+1]!=z||rows[raw*9+3]!=a.spans[i].y||rows[raw*9+7]!=a.areas[i])return -6;
    ++raw;int* o=output+12*i;o[0]=x;o[1]=z;o[2]=a.spans[i].y;o[3]=a.spans[i].h;o[4]=before[i];o[5]=a.areas[i];o[6]=dist[i];o[7]=seed[i];
    for(int d=0;d<4;++d){int con=rcGetCon(a.spans[i],d);o[8+d]=-1;
     if(con!=RC_NOT_CONNECTED){int nx=x+rcGetDirOffsetX(d),nz=z+rcGetDirOffsetY(d);if(nx<0||nx>=W||nz<0||nz>=H)return -7;o[8+d]=a.cells[nx+nz*W].index+con;}
    }
   }
  }
  while(raw<n&&!rows[raw*9+6])++raw;if(raw!=n)return -8;
  *eventCount=trace.count;return ns;
 }catch(...){return -9;}
}
// Each output row: candidate ordinal (-1=union), fixed-cell ordinal,smin,smax,area.
// Original IDs, vertices and signed normals remain driver evidence, never classification inputs.
extern "C" int provenance_raster(const float* triangles,int count,int* output,int outputRows,unsigned char* marks){
 try {
  if(!triangles||!output||!marks||count<0||count>MAX_TRI||outputRows<0)return -1;
  rcContext c(false);rcHeightfield united;if(!create(c,united))return -2;
  int used=0;const int idx[3]={0,1,2};
  auto collect=[&](const rcHeightfield& h,int ordinal)->bool{
   for(int j=0;j<17;++j)for(rcSpan* s=h.spans[CELLS[j][0]+CELLS[j][1]*W];s;s=s->next){
    if(used>=outputRows)return false;int* o=output+5*used++;o[0]=ordinal;o[1]=j;o[2]=s->smin;o[3]=s->smax;o[4]=s->area;
   }return true;
  };
  for(int t=0;t<count;++t){const float* v=triangles+9*t;
   for(int k=0;k<9;++k)if(!std::isfinite(v[k]))return -3;
   unsigned char area=RC_NULL_AREA;rcMarkWalkableTriangles(&c,15.f,v,3,idx,1,&area);marks[t]=area;
   rcHeightfield single;if(!create(c,single))return -2;
   if(!rcRasterizeTriangle(&c,v,v+3,v+6,area,single,2)||!rcRasterizeTriangle(&c,v,v+3,v+6,area,united,2))return -4;
   if(!collect(single,t))return -5;
  }
  if(!collect(united,-1))return -5;return used;
 }catch(...){return -9;}
}
