// Tiny authored component control over the actual pinned Recast rasterizer.
// No copied raster implementation, path query, Apple SDK, live sensor or room trial.
#include "Recast.h"
#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <vector>

struct Mesh { std::vector<float> vertices; std::vector<int> triangles; std::vector<unsigned char> floor; };
struct Observation {
    int spans=0, floorAreas=0, obstacleTopPromotions=0, obstacleSpans=0;
    std::vector<int> grid;
};
static void require(bool ok,const char* text) { if(!ok) { std::fprintf(stderr,"FAIL: %s\n",text); std::exit(1); } }
static void add(Mesh& mesh,const std::vector<float>& v,const std::vector<int>& t,bool floor) {
    const int offset=static_cast<int>(mesh.vertices.size()/3);
    mesh.vertices.insert(mesh.vertices.end(),v.begin(),v.end());
    for(int index:t) mesh.triangles.push_back(index+offset);
    for(std::size_t i=0;i<t.size()/3;++i) mesh.floor.push_back(floor?1:0);
}
static Mesh originalFloor() {
    Mesh m;add(m,{-1,0,-1,-1,0,1,1,0,1,1,0,-1},{0,1,2,0,2,3},true);return m;
}
static Mesh box(float low,float high) {
    Mesh m;
    add(m,{-0.3f,low,-0.3f,0.3f,low,-0.3f,0.3f,low,0.3f,-0.3f,low,0.3f,
           -0.3f,high,-0.3f,0.3f,high,-0.3f,0.3f,high,0.3f,-0.3f,high,0.3f},
          {0,1,2,0,2,3,4,7,6,4,6,5,0,4,5,0,5,1,1,5,6,1,6,2,2,6,7,2,7,3,3,7,4,3,4,0},false);
    return m;
}
static Mesh joined(const Mesh& a,const Mesh& b) {
    Mesh out=a; const int offset=static_cast<int>(a.vertices.size()/3);
    out.vertices.insert(out.vertices.end(),b.vertices.begin(),b.vertices.end());
    for(int i:b.triangles)out.triangles.push_back(i+offset);
    out.floor.insert(out.floor.end(),b.floor.begin(),b.floor.end());return out;
}
struct Heightfield {
    rcHeightfield* value;
    explicit Heightfield(const Mesh& mesh,bool priorities,const std::vector<int>& order):value(rcAllocHeightfield()) {
        require(value!=0,"heightfield allocation");rcContext context(false);
        const float min[3]={-1,-0.025f,-1},max[3]={1,3,1};
        require(rcCreateHeightfield(&context,*value,80,80,min,max,0.025f,0.025f),"heightfield initialization");
        std::vector<int> triangles;std::vector<unsigned char> areas;
        for(int i:order) {
            require(i>=0 && static_cast<std::size_t>(i)<mesh.floor.size(),"permutation index");
            for(int j=0;j<3;++j)triangles.push_back(mesh.triangles[3*i+j]);
            areas.push_back(mesh.floor[i] ? (priorities?1:RC_WALKABLE_AREA) : RC_NULL_AREA);
        }
        // Same classified-mode calls/labels as blind_detour_exclusion.cpp. We
        // deliberately do not invoke or reproduce upstream raster internals.
        rcClearUnwalkableTriangles(&context,15,mesh.vertices.data(),static_cast<int>(mesh.vertices.size()/3),
                                  triangles.data(),static_cast<int>(areas.size()),areas.data());
        if(priorities)for(std::size_t i=0;i<order.size();++i)if(mesh.floor[order[i]]==0)areas[i]=2;
        require(rcRasterizeTriangles(&context,mesh.vertices.data(),static_cast<int>(mesh.vertices.size()/3),
                    triangles.data(),areas.data(),static_cast<int>(areas.size()),*value,1),"actual upstream rasterization");
    }
    ~Heightfield(){rcFreeHeightField(value);}
    Heightfield(const Heightfield&)=delete; Heightfield& operator=(const Heightfield&)=delete;
};
static std::vector<int> natural(const Mesh& m) { std::vector<int> r;for(std::size_t i=0;i<m.floor.size();++i)r.push_back(static_cast<int>(i));return r; }
static Observation inspect(Heightfield& field,const Heightfield* obstacle,bool priorities) {
    Observation r;const unsigned char floorArea=priorities?1:RC_WALKABLE_AREA;
    for(int i=0;i<80*80;++i) {
        const rcSpan* source=obstacle?obstacle->value->spans[i]:0;
        for(const rcSpan* o=source;o;o=o->next)++r.obstacleSpans;
        for(rcSpan* s=field.value->spans[i];s;s=s->next) {
            ++r.spans;
            if(s->area==floorArea) {
                ++r.floorAreas;
                for(const rcSpan* o=source;o;o=o->next) {
                    // This is only a lattice-label witness. Touching/merged
                    // obstacle top has exactly the upstream obstacle smax.
                    if(s->smax==o->smax){++r.obstacleTopPromotions;break;}
                }
            }
            if(priorities)s->area=s->area==1?RC_WALKABLE_AREA:RC_NULL_AREA;
            r.grid.push_back(i);r.grid.push_back(s->smin);r.grid.push_back(s->smax);r.grid.push_back(s->area);
        }
    }
    return r;
}
static void print(const char* fixture,const char* order,const char* mode,const Observation& o,const std::vector<int>& permutation) {
    std::printf("{\"fixture\":\"%s\",\"order\":\"%s\",\"mode\":\"%s\",\"spans\":%d,\"floorAreas\":%d,\"obstacleSpans\":%d,\"obstacleTopPromotions\":%d,\"triangleOrder\":[",fixture,order,mode,o.spans,o.floorAreas,o.obstacleSpans,o.obstacleTopPromotions);
    for(std::size_t i=0;i<permutation.size();++i)std::printf("%s%d",i?",":"",permutation[i]);
    std::printf("]}\n");
}
int main() {
    const Mesh floor=originalFloor();const std::vector<int> floorOrder=natural(floor);
    Heightfield floorField(floor,true,floorOrder);const Observation positive=inspect(floorField,0,true);
    require(positive.floorAreas==6400,"floor-only positive must retain all 80x80 floor columns");
    print("floor-only","natural","priorities",positive,floorOrder);
    int cases=1,naivePromotions=0;bool lowLegacyWitness=false,bedLegacyWitness=false;
    for(int variant=0;variant<3;++variant) {
        const char* name=variant==0?"touching-low-1cm":variant==1?"touching-bed-65cm":"separated-box-55to65cm";
        const Mesh obstacle=box(variant==2?0.55f:0.f,variant==0?0.01f:0.65f);
        const std::vector<int> obstacleOrder=natural(obstacle);
        Heightfield obstacleOnly(obstacle,true,obstacleOrder);
        const Observation negative=inspect(obstacleOnly,0,true);
        require(negative.floorAreas==0,"obstacle-only negative cannot gain floor label");
        print(name,"obstacle-only","priorities",negative,obstacleOrder);++cases;
        const Mesh mesh=joined(floor,obstacle);const std::vector<int> base=natural(mesh);
        std::vector<std::vector<int> > permutations;
        permutations.push_back(base);
        std::vector<int> objectFirst(base.begin()+2,base.end());objectFirst.push_back(0);objectFirst.push_back(1);permutations.push_back(objectFirst);
        std::vector<int> reverse=base;std::reverse(reverse.begin(),reverse.end());permutations.push_back(reverse);
        std::vector<int> interleaved={0,2,1};for(std::size_t i=3;i<base.size();++i)interleaved.push_back(static_cast<int>(i));permutations.push_back(interleaved);
        for(int rotate:{1,5,11}){std::vector<int> r=base;std::rotate(r.begin(),r.begin()+rotate,r.end());permutations.push_back(r);}
        std::vector<int> evensOdds;for(int parity=0;parity<2;++parity)for(std::size_t i=parity;i<base.size();i+=2)evensOdds.push_back(static_cast<int>(i));permutations.push_back(evensOdds);
        const char* names[]={"floor-first","obstacle-first","reversed","interleaved","rotate-1","rotate-5","rotate-11","even-odd"};
        std::vector<int> referenceGrid;
        for(std::size_t p=0;p<permutations.size();++p)for(int mode=0;mode<2;++mode) {
            const bool priorities=mode==1;
            Heightfield originalObstacle(obstacle,true,obstacleOrder),combined(mesh,priorities,permutations[p]);
            const Observation o=inspect(combined,&originalObstacle,priorities);
            print(name,names[p],priorities?"priorities":"naive-floor63-obstacle0",o,permutations[p]);++cases;
            require(o.obstacleSpans>0,"nonempty source obstacle raster");
            if(priorities) {
                require(o.obstacleTopPromotions==0,"obstacle top acquired original-floor label");
                require(o.floorAreas>0,"unaffected original floor remains positive");
                if(p==0)referenceGrid=o.grid;else require(referenceGrid==o.grid,"classified remapped raster depends on triangle order");
            }else {
                naivePromotions+=o.obstacleTopPromotions;
                if(variant==0 && o.obstacleTopPromotions>0)lowLegacyWitness=true;
                if(variant==1 && o.obstacleTopPromotions>0)bedLegacyWitness=true;
            }
        }
    }
    require(lowLegacyWitness,"control must expose naive low-object promotion");
    require(bedLegacyWitness,"control must expose naive touching-bed promotion");
    std::printf("{\"summary\":true,\"passed\":true,\"cases\":%d,\"naivePromotionWitnessCount\":%d,\"classifiedObstacleTopPromotions\":0,\"appleExecuted\":false,\"fullPathExecuted\":false,\"realRoomExecuted\":false,\"physicalAuthority\":false}\n",cases,naivePromotions);
    return 0;
}
