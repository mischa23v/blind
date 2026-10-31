// Authored native tests. Not executed until independent source review/admission.
#include "exact_seed_radius_veto.h"
#include "RecastAlloc.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>
#include <utility>
#include <climits>

#define REQUIRE(x) do { if (!(x)) { std::fprintf(stderr,"FAIL line %d: %s\n",__LINE__,#x); std::exit(1); } } while (0)
static int checks = 0;
static void passed(const char* name) { ++checks; std::printf("PASS %s\n",name); }
struct Field {
    rcCompactHeightfield* c = rcAllocCompactHeightfield();
    Field(int w,int h,int missingX=-1,int missingZ=-1) {
        REQUIRE(c);c->width=w;c->height=h;c->cs=.025f;c->ch=.025f;
        c->spanCount=w*h-((missingX>=0 && missingZ>=0)?1:0);
        c->cells=(rcCompactCell*)rcAlloc(sizeof(rcCompactCell)*w*h,RC_ALLOC_PERM);
        c->spans=(rcCompactSpan*)rcAlloc(sizeof(rcCompactSpan)*c->spanCount,RC_ALLOC_PERM);
        c->areas=(unsigned char*)rcAlloc(c->spanCount,RC_ALLOC_PERM);
        REQUIRE(c->cells && c->spans && c->areas);
        std::memset(c->cells,0,sizeof(rcCompactCell)*w*h);
        std::memset(c->spans,0,sizeof(rcCompactSpan)*c->spanCount);
        std::memset(c->areas,RC_WALKABLE_AREA,c->spanCount);
        int cursor=0;
        for(int z=0;z<h;++z)for(int x=0;x<w;++x){
            auto& cell=c->cells[x+z*w];cell.index=cursor;
            if(x==missingX && z==missingZ)continue;
            cell.count=1;auto& span=c->spans[cursor++];span.y=1;span.h=100;
            for(int d=0;d<4;++d)rcSetCon(span,d,RC_NOT_CONNECTED);
        }
        for(int z=0;z<h;++z)for(int x=0;x<w;++x){
            auto& cell=c->cells[x+z*w];if(!cell.count)continue;
            for(int d=0;d<4;++d){int nx=x+rcGetDirOffsetX(d),nz=z+rcGetDirOffsetY(d);
                if(nx>=0 && nx<w && nz>=0 && nz<h && c->cells[nx+nz*w].count)
                    rcSetCon(c->spans[cell.index],d,0);
            }
        }
    }
    ~Field(){rcFreeCompactHeightfield(c);}
    int index(int x,int z)const {REQUIRE(c->cells[x+z*c->width].count==1);return c->cells[x+z*c->width].index;}
};
static std::vector<unsigned char> areas(const rcCompactHeightfield& c){return {c.areas,c.areas+c.spanCount};}
// Independent O(candidates * seed-count) integer reference, deliberately NOT the
// adapter's offset kernel. No sqrt, nearest propagated label, or float threshold.
static std::vector<std::pair<int,int>> originalSeeds(const rcCompactHeightfield& c){
    std::vector<std::pair<int,int>> seeds;
    for(int z=-1;z<=c.height;++z)for(int x=-1;x<=c.width;++x)
        if(x==-1 || z==-1 || x==c.width || z==c.height)seeds.push_back({x,z});
    for(int z=0;z<c.height;++z)for(int x=0;x<c.width;++x){
        auto cell=c.cells[x+z*c.width];if(!cell.count)continue;
        bool seed=c.areas[cell.index]==RC_NULL_AREA;
        for(int d=0;d<4;++d){
            if(rcGetCon(c.spans[cell.index],d)==RC_NOT_CONNECTED){seed=true;continue;}
            int nx=x+rcGetDirOffsetX(d),nz=z+rcGetDirOffsetY(d);
            if(c.areas[c.cells[nx+nz*c.width].index]==RC_NULL_AREA)seed=true;
        }
        if(seed)seeds.push_back({x,z});
    }
    return seeds;
}
static BNSeedRadiusVetoReceipt compareOracle(Field& f,int radius){
    auto& c=*f.c;auto seeds=originalSeeds(c);BNSeedRadiusVeto veto;BNSeedRadiusVetoReceipt r={};
    REQUIRE(veto.prepare(c,radius,10000000,r));rcContext context;
    REQUIRE(rcErodeWalkableArea(&context,radius,c));auto stock=areas(c);
    REQUIRE(veto.apply(c,r));REQUIRE(r.status==BN_SEED_RADIUS_APPLIED);
    REQUIRE(r.work_performed<=r.work_bound && r.work_bound<=r.work_limit);
    int kept=0;
    for(int z=0;z<c.height;++z)for(int x=0;x<c.width;++x){
        auto cell=c.cells[x+z*c.width];if(!cell.count)continue;
        bool keep=stock[cell.index]!=0;
        for(auto seed:seeds){long long dx=seed.first-x,dz=seed.second-z;
            if(dx*dx+dz*dz<static_cast<long long>(radius)*radius)keep=false;}
        REQUIRE(c.areas[cell.index]==(keep?stock[cell.index]:0));kept+=keep;
    }
    REQUIRE(kept==r.exact_keep_count);return r;
}
static void thresholdFixture(){
    Field f(25,25);auto& c=*f.c;
    // Two reciprocal missing connections create exactly two internal seeds.
    rcSetCon(c.spans[f.index(12,12)],2,RC_NOT_CONNECTED);
    rcSetCon(c.spans[f.index(13,12)],0,RC_NOT_CONNECTED);
    BNSeedRadiusVeto veto;BNSeedRadiusVetoReceipt r={};
    REQUIRE(veto.prepare(c,3,10000000,r));rcContext context;REQUIRE(rcErodeWalkableArea(&context,3,c));
    // Stock chamfer retains d^2=8 at its equality; the extra disk veto removes it.
    REQUIRE(c.areas[f.index(10,14)]!=0 && c.areas[f.index(9,12)]!=0 && c.areas[f.index(9,13)]!=0);
    REQUIRE(veto.apply(c,r));REQUIRE(c.areas[f.index(10,14)]==0); // R^2-1 = 8
    REQUIRE(c.areas[f.index(9,12)]!=0); // R^2 = 9, equality retained
    REQUIRE(c.areas[f.index(9,13)]!=0); // R^2+1 = 10
    REQUIRE(r.additional_rejected_count>0);passed("threshold R2-1 R2 R2+1 and chamfer witness");
}
static void refusalFixture(int variant,int expected){
    Field f(7,7);auto& c=*f.c;
    if(variant==0)c.cells[0].count=2;
    if(variant==1)c.spans[f.index(3,3)].y=2;
    if(variant==2)rcSetCon(c.spans[f.index(3,3)],0,RC_NOT_CONNECTED); // one-way
    if(variant==3)rcSetCon(c.spans[f.index(3,3)],0,1);
    if(variant==4)rcSetCon(c.spans[f.index(0,0)],0,0); // outside
    if(variant==5)c.cells[4].index=50;
    if(variant==6)c.width=INT_MAX;
    if(variant==7)c.cs=0;
    BNSeedRadiusVeto veto;BNSeedRadiusVetoReceipt r={};auto before=areas(c);
    REQUIRE(!veto.prepare(c,3,10000000,r));REQUIRE(r.status==expected);REQUIRE(areas(c)==before);
    passed("typed domain/topology refusal without area mutation");
}
static int allocationCalls=0,failAllocationAt=-1;
static void* testAlloc(size_t size,rcAllocHint){return allocationCalls++==failAllocationAt?nullptr:std::malloc(size);}
static void testFree(void* p){std::free(p);}
static void allocationFixture(){
    for(int i=0;i<4;++i){Field f(7,7);BNSeedRadiusVetoReceipt r={};auto before=areas(*f.c);
        allocationCalls=0;failAllocationAt=i;rcAllocSetCustom(testAlloc,testFree);
        {BNSeedRadiusVeto veto;REQUIRE(!veto.prepare(*f.c,3,10000000,r));REQUIRE(r.status==BN_SEED_RADIUS_ALLOCATION_FAILED);}
        rcAllocSetCustom(nullptr,nullptr);REQUIRE(areas(*f.c)==before);
    }passed("four adapter allocations fail closed");
}
static void workFixture(){
    Field f(15,15);BNSeedRadiusVeto veto;BNSeedRadiusVetoReceipt r={};
    REQUIRE(veto.prepare(*f.c,3,1,r));rcContext context;REQUIRE(rcErodeWalkableArea(&context,3,*f.c));auto stock=areas(*f.c);
    REQUIRE(!veto.apply(*f.c,r));REQUIRE(r.status==BN_SEED_RADIUS_WORK_LIMIT);
    REQUIRE(r.work_bound>r.work_limit && r.work_performed==0 && areas(*f.c)==stock);
    for(auto limit:{0ULL,10000001ULL}){BNSeedRadiusVeto v;BNSeedRadiusVetoReceipt q={};
        REQUIRE(!v.prepare(*f.c,3,limit,q));REQUIRE(q.status==BN_SEED_RADIUS_WORK_LIMIT);}
    passed("checked work refusal before additional mutation and invalid budget");
}
static void frozenFixtures(const char* filename){
    FILE* in=std::fopen(filename,"r");REQUIRE(in);int profiles=0;REQUIRE(std::fscanf(in,"%d",&profiles)==1 && profiles==6);
    for(int p=0;p<profiles;++p){int w,h,n,radius,real,stockCount,exactCount;
        REQUIRE(std::fscanf(in,"%d %d %d %d %d %d %d",&w,&h,&n,&radius,&real,&stockCount,&exactCount)==7);
        // Field owns allocations, then replace its generated arrays with exact capture.
        Field f(w,h);auto& c=*f.c;REQUIRE(n<=w*h);c.spanCount=n;
        unsigned words[5];for(auto& word:words)REQUIRE(std::fscanf(in,"%u",&word)==1);
        static_assert(sizeof(float)==sizeof(unsigned),"Float32 fixture words");
        std::memcpy(&c.cs,words,4);std::memcpy(&c.ch,words+1,4);std::memcpy(c.bmin,words+2,12);
        for(int i=0;i<w*h;++i){unsigned index,count;REQUIRE(std::fscanf(in,"%u %u",&index,&count)==2);c.cells[i].index=index;c.cells[i].count=count;}
        std::vector<unsigned char> expectedStock(n),expectedKeep(n);
        for(int i=0;i<n;++i){unsigned y,height,area,stock,keep;int con[4];
            REQUIRE(std::fscanf(in,"%u %u %u %u %u %d %d %d %d",&y,&height,&area,&stock,&keep,&con[0],&con[1],&con[2],&con[3])==9);
            c.spans[i].y=y;c.spans[i].h=height;c.areas[i]=area;expectedStock[i]=stock;expectedKeep[i]=keep;
            for(int d=0;d<4;++d)rcSetCon(c.spans[i],d,con[d]<0?RC_NOT_CONNECTED:0);
        }
        BNSeedRadiusVeto veto;BNSeedRadiusVetoReceipt receipt={};REQUIRE(veto.prepare(c,radius,10000000,receipt));
        REQUIRE(receipt.real_seed_count==real);rcContext context;REQUIRE(rcErodeWalkableArea(&context,radius,c));
        REQUIRE(areas(c)==expectedStock);REQUIRE(veto.apply(c,receipt));
        REQUIRE(receipt.stock_keep_count==stockCount && receipt.exact_keep_count==exactCount);
        REQUIRE(receipt.work_performed<=receipt.work_bound && receipt.work_bound<=10000000);
        for(int i=0;i<n;++i)REQUIRE(c.areas[i]==(expectedKeep[i]?expectedStock[i]:0));
        passed("frozen full-layout stock area and all exact mask bits");
    }REQUIRE(std::fclose(in)==0);
}
int main(int argc,char** argv){
    REQUIRE(argc==2);thresholdFixture();
    {Field f(17,17);f.c->areas[f.index(8,8)]=RC_NULL_AREA;f.c->areas[f.index(5,5)]=7;
        compareOracle(f,3);passed("null/nonzero area diagonal ties and perimeter oracle");}
    {Field f(17,17,8,8);auto r=compareOracle(f,3);REQUIRE(r.real_seed_count==68);passed("absent column is not an independent seed");}
    {Field f(3,3);auto r=compareOracle(f,3);REQUIRE(r.stock_keep_count==0 && r.exact_keep_count==0);passed("valid zero keep mask");}
    for(int i=0;i<8;++i)refusalFixture(i,i<2?BN_SEED_RADIUS_UNSUPPORTED_LAYER:i<6?BN_SEED_RADIUS_INVALID_TOPOLOGY:BN_SEED_RADIUS_INVALID_INPUT);
    workFixture();allocationFixture();frozenFixtures(argv[1]);
    std::printf("TOTAL %d named fixture groups passed (native only when actually executed)\n",checks);return 0;
}
