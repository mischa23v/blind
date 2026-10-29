// Actual native compact-field helper qualification; no route queries or Swift.
#define BN_ENVELOPE_TEST_OBSERVER 1
#include "exact_seed_radius_envelope.h"
#define main legacyDiskMain
#include "legacy_disk_tests.cpp"
#undef main
#include <algorithm>
static unsigned long long oracleChecks=0;
static int parityCases=0;
static void compareAdapters(Field& f,int radius,const std::vector<unsigned char>* capturedStock=nullptr,
                            const std::vector<unsigned char>* capturedKeep=nullptr){
    auto& c=*f.c;const auto original=areas(c);const auto seeds=originalSeeds(c);
    std::vector<unsigned char> stock,oldFinal;BNSeedRadiusVetoReceipt old={};
    {BNSeedRadiusVeto disk;REQUIRE(disk.prepare(c,radius,10000000,old));rcContext ctx;
        REQUIRE(rcErodeWalkableArea(&ctx,radius,c));stock=areas(c);REQUIRE(disk.apply(c,old));oldFinal=areas(c);}
    std::memcpy(c.areas,original.data(),original.size());
    const std::vector<unsigned char> cellsBefore((unsigned char*)c.cells,(unsigned char*)(c.cells+c.width*c.height));
    const std::vector<unsigned char> spansBefore((unsigned char*)c.spans,(unsigned char*)(c.spans+c.spanCount));
    BNSeedRadiusEnvelopeReceipt next={};
    {BNSeedRadiusEnvelope envelope;REQUIRE(envelope.prepare(c,radius,10000000,next));
        REQUIRE(next.schema==2&&next.algorithm==1&&next.work_unit==1);
        REQUIRE(next.real_seed_count==old.real_seed_count&&next.exterior_seed_count==old.exterior_seed_count);
        REQUIRE(next.common_y_voxel==old.common_y_voxel&&next.radius_cells==old.radius_cells);
        std::vector<unsigned char> independent((c.width+2)*(c.height+2),0);
        for(auto seed:seeds)independent[(seed.first+1)+(seed.second+1)*(c.width+2)]=1;
        REQUIRE(envelope.paddedCells()==independent.size());
        REQUIRE(!std::memcmp(envelope.frozenSeeds(),independent.data(),independent.size()));
        rcContext ctx;REQUIRE(rcErodeWalkableArea(&ctx,radius,c));REQUIRE(areas(c)==stock);
        if(capturedStock)REQUIRE(stock==*capturedStock);
        REQUIRE(envelope.apply(c,next));REQUIRE(areas(c)==oldFinal);
        REQUIRE(next.status==BN_SEED_RADIUS_APPLIED&&next.work_performed<=next.work_bound&&next.work_bound<=next.work_limit);
        REQUIRE(next.stock_keep_count==old.stock_keep_count&&next.exact_keep_count==old.exact_keep_count);
        REQUIRE(next.additional_rejected_count==old.additional_rejected_count);
        for(int z=0;z<c.height;++z)for(int x=0;x<c.width;++x){auto cell=c.cells[x+z*c.width];if(!cell.count)continue;
            bool keep=stock[cell.index]!=0;
            if(keep)for(auto seed:seeds){REQUIRE(++oracleChecks<=300000000ULL);long long dx=x-seed.first,dz=z-seed.second;
                if(dx*dx+dz*dz<static_cast<long long>(radius)*radius){keep=false;break;}}
            REQUIRE(c.areas[cell.index]==(keep?stock[cell.index]:0));
            if(capturedKeep)REQUIRE(keep==((*capturedKeep)[cell.index]!=0));
        }
    }
    REQUIRE(!std::memcmp(c.cells,cellsBefore.data(),cellsBefore.size()));
    REQUIRE(!std::memcmp(c.spans,spansBefore.data(),spansBefore.size()));++parityCases;
}
static void capturedEnvelope(const char* file){
    FILE* in=std::fopen(file,"r");REQUIRE(in);int profiles=0;REQUIRE(std::fscanf(in,"%d",&profiles)==1&&profiles==6);
    for(int p=0;p<profiles;++p){int w,h,n,r,real,sc,ec;REQUIRE(std::fscanf(in,"%d %d %d %d %d %d %d",&w,&h,&n,&r,&real,&sc,&ec)==7);
        REQUIRE(w>0&&h>0&&w*h<=250000&&n>0&&n<=65536);Field f(w,h);auto& c=*f.c;c.spanCount=n;
        unsigned words[5];for(auto& word:words)REQUIRE(std::fscanf(in,"%u",&word)==1);
        std::memcpy(&c.cs,words,4);std::memcpy(&c.ch,words+1,4);std::memcpy(c.bmin,words+2,12);
        for(int i=0;i<w*h;++i){unsigned index,count;REQUIRE(std::fscanf(in,"%u %u",&index,&count)==2);c.cells[i].index=index;c.cells[i].count=count;}
        std::vector<unsigned char> stock(n),keep(n);
        for(int i=0;i<n;++i){unsigned y,hh,area,s,k;int con[4];REQUIRE(std::fscanf(in,"%u %u %u %u %u %d %d %d %d",&y,&hh,&area,&s,&k,&con[0],&con[1],&con[2],&con[3])==9);
            c.spans[i].y=y;c.spans[i].h=hh;c.areas[i]=area;stock[i]=s;keep[i]=k;
            for(int d=0;d<4;++d)rcSetCon(c.spans[i],d,con[d]<0?RC_NOT_CONNECTED:0);}
        compareAdapters(f,r,&stock,&keep);std::printf("ENVELOPE captured profile %d all bits passed\n",p);
    }REQUIRE(std::fclose(in)==0);
}
static int liveAllocations=0,newCalls=0,newFail=-1;
static void* trackedAlloc(size_t n,rcAllocHint){if(newCalls++==newFail)return nullptr;void* p=std::malloc(n);if(p)++liveAllocations;return p;}
static void trackedFree(void* p){if(p)--liveAllocations;std::free(p);}
static void envelopeRefusals(){
    for(int variant=0;variant<8;++variant){Field f(7,7);auto& c=*f.c;
        if(variant==0)c.cells[0].count=2;if(variant==1)c.spans[f.index(3,3)].y=2;
        if(variant==2)rcSetCon(c.spans[f.index(3,3)],0,RC_NOT_CONNECTED);
        if(variant==3)rcSetCon(c.spans[f.index(3,3)],0,1);
        if(variant==4)rcSetCon(c.spans[f.index(0,0)],0,0);
        if(variant==5)c.cells[4].index=50;if(variant==6)c.width=INT_MAX;if(variant==7)c.cs=0;
        auto before=areas(c);BNSeedRadiusEnvelope e;BNSeedRadiusEnvelopeReceipt r={};
        REQUIRE(!e.prepare(c,3,10000000,r));REQUIRE(r.schema==2&&r.status==(variant<2?BN_SEED_RADIUS_UNSUPPORTED_LAYER:variant<6?BN_SEED_RADIUS_INVALID_TOPOLOGY:BN_SEED_RADIUS_INVALID_INPUT));REQUIRE(areas(c)==before);
    }
    for(int fail=0;fail<7;++fail){Field f(7,7);auto before=areas(*f.c);newCalls=liveAllocations=0;newFail=fail;rcAllocSetCustom(trackedAlloc,trackedFree);
        {BNSeedRadiusEnvelope e;BNSeedRadiusEnvelopeReceipt r={};REQUIRE(!e.prepare(*f.c,3,10000000,r));REQUIRE(r.status==BN_SEED_RADIUS_ALLOCATION_FAILED);
            REQUIRE(!e.prepare(*f.c,3,10000000,r));REQUIRE(r.status==BN_SEED_RADIUS_INVALID_INPUT&&newCalls==7);}
        rcAllocSetCustom(nullptr,nullptr);REQUIRE(liveAllocations==0&&newCalls==7&&areas(*f.c)==before);
    }
    for(auto limit:{0ULL,1ULL,10000001ULL}){Field f(7,7);auto before=areas(*f.c);BNSeedRadiusEnvelope e;BNSeedRadiusEnvelopeReceipt r={};REQUIRE(!e.prepare(*f.c,3,limit,r));REQUIRE(r.status==BN_SEED_RADIUS_WORK_LIMIT&&areas(*f.c)==before);}
    for(int selector=0;selector<3;++selector){Field f(500,1);auto before=areas(*f.c);BNSeedRadiusEnvelope e;BNSeedRadiusEnvelopeReceipt r={};REQUIRE(e.prepare(*f.c,3,10000000,r));
        if(selector==0)r.schema=1;if(selector==1)r.algorithm=0;if(selector==2)r.work_unit=0;
        REQUIRE(!e.apply(*f.c,r));REQUIRE(r.status==BN_SEED_RADIUS_INVALID_TOPOLOGY&&areas(*f.c)==before);}
    {Field f(15,15);BNSeedRadiusEnvelope e;BNSeedRadiusEnvelopeReceipt r={};REQUIRE(e.prepare(*f.c,3,10000000,r));rcContext ctx;
        REQUIRE(rcErodeWalkableArea(&ctx,3,*f.c));auto stock=areas(*f.c);r.work_limit=1;
        REQUIRE(!e.apply(*f.c,r));REQUIRE(r.status==BN_SEED_RADIUS_WORK_LIMIT&&r.work_performed==0&&areas(*f.c)==stock);}
    {Field f(256,257);BNSeedRadiusEnvelope e;BNSeedRadiusEnvelopeReceipt r={};auto before=areas(*f.c);REQUIRE(!e.prepare(*f.c,3,10000000,r));REQUIRE(r.status==BN_SEED_RADIUS_INVALID_INPUT&&areas(*f.c)==before);}
    {Field f(50000,1);BNSeedRadiusEnvelope e;BNSeedRadiusEnvelopeReceipt r={};auto before=areas(*f.c);REQUIRE(!e.prepare(*f.c,3,10000000,r));REQUIRE(r.status==BN_ENVELOPE_MEMORY_LIMIT&&areas(*f.c)==before);}
    std::puts("ENVELOPE scope, seven allocation failures, work and schema refusals passed");
}
static void largerScope(){
    // Same production minimum2.5cm cell size;201 cells~5m and241 cells~6m.
    for(int side:{201,241}){Field f(side,side);auto& c=*f.c;const auto seeds=originalSeeds(c);const auto original=areas(c);BNSeedRadiusVetoReceipt old={};
        {BNSeedRadiusVeto e;REQUIRE(e.prepare(c,12,10000000,old));rcContext ctx;REQUIRE(rcErodeWalkableArea(&ctx,12,c));auto stock=areas(c);REQUIRE(!e.apply(c,old));REQUIRE(old.status==BN_SEED_RADIUS_WORK_LIMIT&&areas(c)==stock);}
        std::memcpy(c.areas,original.data(),original.size());BNSeedRadiusEnvelopeReceipt next={};
        {BNSeedRadiusEnvelope e;REQUIRE(e.prepare(c,12,10000000,next));rcContext ctx;REQUIRE(rcErodeWalkableArea(&ctx,12,c));auto stock=areas(c);REQUIRE(e.apply(c,next));
            for(int z=0;z<side;++z)for(int x=0;x<side;++x){const int i=f.index(x,z);bool keep=stock[i]!=0;
                if(keep)for(auto seed:seeds){REQUIRE(++oracleChecks<=300000000ULL);long long dx=x-seed.first,dz=z-seed.second;if(dx*dx+dz*dz<144){keep=false;break;}}
                REQUIRE(c.areas[i]==(keep?stock[i]:0));}
        }std::printf("ENVELOPE authored side=%d diskBound=%llu envelopeWork=%llu keep=%d passed\n",side,old.work_bound,next.work_performed,next.exact_keep_count);
    }
}
static void abiSmoke(){
    // Classified flat source with unchanged body/grid rules; no path call.
    const float v[]={0,0,0,0,0,3,3,0,0,3,0,3};const int t[]={0,1,2,2,1,3};const unsigned char support[]={1,1};
    BNConfig c={.30f,1.75f,.025f,.025f,.05f,15.f,250000,4096};
    BNSeedRadiusEnvelopeReceipt r={};void* h=bn_build_classified_seed_radius_envelope(v,4,t,2,&c,support,10000000,&r);
    REQUIRE(h&&r.schema==2&&r.algorithm==1&&r.work_unit==1&&r.status==BN_SEED_RADIUS_APPLIED&&r.build_succeeded);bn_destroy(h);
    REQUIRE(!bn_build_classified_seed_radius_envelope(v,4,t,2,&c,nullptr,10000000,&r));REQUIRE(!r.build_succeeded);
    REQUIRE(!bn_build_classified_seed_radius_envelope(v,4,t,2,&c,support,0,&r)&&r.status==BN_SEED_RADIUS_WORK_LIMIT);
    BNSeedRadiusVetoReceipt old={};h=bn_build_classified_seed_radius(v,4,t,2,&c,support,10000000,&old);REQUIRE(h&&old.schema==1);bn_destroy(h);
    std::puts("ENVELOPE distinct ABI schema2 and retained disk schema1 passed");
}
int main(int argc,char**argv){REQUIRE(argc==2);REQUIRE(legacyDiskMain(argc,argv)==0);capturedEnvelope(argv[1]);
    for(int mask=0;mask<512;++mask)for(int radius:{1,3}){Field f(7,7);for(int i=0;i<9;++i)if(mask&(1<<i))f.c->areas[f.index(2+i%3,2+i/3)]=0;compareAdapters(f,radius);}
    {Field f(17,17,8,8);compareAdapters(f,3);}
    {Field f(25,25);rcSetCon(f.c->spans[f.index(12,12)],2,RC_NOT_CONNECTED);rcSetCon(f.c->spans[f.index(13,12)],0,RC_NOT_CONNECTED);compareAdapters(f,3);REQUIRE(f.c->areas[f.index(10,14)]==0&&f.c->areas[f.index(9,12)]!=0&&f.c->areas[f.index(9,13)]!=0);}
    {Field f(3,3);compareAdapters(f,3);}
    envelopeRefusals();largerScope();abiSmoke();REQUIRE(parityCases==1033);
    std::printf("ENVELOPE TOTAL adapterParityCases=%d oracleChecks=%llu PASS\n",parityCases,oracleChecks);return 0;
}
