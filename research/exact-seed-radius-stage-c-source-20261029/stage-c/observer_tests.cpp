// Authored tests of the read-only scratch observer; not yet executed.
#include "seed_probe.h"
#include "Recast.h"
#include "RecastAlloc.h"
#include "hook_test_digest.hpp"
#include <cstdio>
#include <cstdlib>
#include <cstring>
extern "C" void blind_seed_probe_stock(const rcCompactHeightfield&,const unsigned char*,int,int);
extern "C" void blind_seed_probe_after_veto(const rcCompactHeightfield&,const BNSeedRadiusVetoReceipt&);
static int checks=0,groups=0;
static void pass(const char* name){++groups;std::printf("PASS observer/%s\n",name);}
static void check(bool yes){if(!yes){std::fprintf(stderr,"scratch seed observer check %d failed\n",checks+1);std::abort();}++checks;}
struct Fixture {
    rcCompactHeightfield field;
    unsigned char distance[9]={0,0,0,0,2,0,0,0,0};
    Fixture(){
        field.width=3;field.height=3;field.spanCount=9;field.cs=.025f;field.ch=.025f;
        field.bmin[0]=field.bmin[1]=field.bmin[2]=0;
        field.cells=static_cast<rcCompactCell*>(rcAlloc(sizeof(rcCompactCell)*9,RC_ALLOC_PERM));
        field.spans=static_cast<rcCompactSpan*>(rcAlloc(sizeof(rcCompactSpan)*9,RC_ALLOC_PERM));
        field.areas=static_cast<unsigned char*>(rcAlloc(9,RC_ALLOC_PERM));
        if(!field.cells || !field.spans || !field.areas)std::abort();
        std::memset(field.spans,0,sizeof(rcCompactSpan)*9);
        for(int z=0;z<3;++z)for(int x=0;x<3;++x){int i=x+z*3;field.cells[i].index=i;field.cells[i].count=1;field.spans[i].y=2;field.spans[i].h=255;field.areas[i]=63;
            for(int d=0;d<4;++d){int nx=x+rcGetDirOffsetX(d),nz=z+rcGetDirOffsetY(d);rcSetCon(field.spans[i],d,nx>=0&&nx<3&&nz>=0&&nz<3?0:RC_NOT_CONNECTED);}}
    }
    void originalErosion(){for(int i=0;i<9;++i)field.areas[i]=i==4?63:0;}
    bool originalAreas(){for(int i=0;i<9;++i)if(field.areas[i]!=(i==4?63:0))return false;return true;}
    void phases(){blind_seed_probe_stock(field,distance,1,0);originalErosion();blind_seed_probe_stock(field,distance,1,1);}
};
struct Receipt {
    unsigned char digest[32]={};int original=-1,expected=-1,observed=-1,matched=-1,vetoObserved=-1,vetoMatch=-1,invalid=-1;
    bool read(){return bn_seed_probe_receipt(digest,&original,&expected,&observed,&matched,&vetoObserved,&vetoMatch,&invalid)!=0;}
};
static BNSeedRadiusVetoReceipt production(int exact=1){
    BNSeedRadiusVetoReceipt r={};r.schema=1;r.status=BN_SEED_RADIUS_APPLIED;
    r.width=r.height=3;r.span_count=9;r.radius_cells=1;r.common_y_voxel=2;
    r.real_seed_count=8;r.exterior_seed_count=16;r.stock_keep_count=1;r.exact_keep_count=exact;
    r.additional_rejected_count=1-exact;r.work_limit=10000000;r.work_bound=1;r.work_performed=1;return r;
}
int main(){
    const unsigned char keep[9]={0,0,0,0,1,0,0,0,0},remove[9]={};
    {Fixture f;check(bn_seed_probe_begin(0,0,kLayoutHash,keep,9)==1);f.phases();Receipt r;
        check(r.read());check(r.original==1&&r.expected==1&&r.vetoObserved==0&&r.vetoMatch==0&&r.invalid==0);
        check(std::memcmp(r.digest,kLayoutHash,32)==0);check(f.originalAreas());pass("stock-only-read-only");}
    {Fixture f;check(bn_seed_probe_begin(0,1,kLayoutHash,keep,9)==1);f.phases();Receipt r;
        check(!r.read());check(r.vetoObserved==0);check(f.originalAreas());
        blind_seed_probe_after_veto(f.field,production());check(r.read());check(r.vetoObserved==1&&r.vetoMatch==1&&r.observed==1);
        check(f.originalAreas());pass("candidate-requires-post-veto-every-bit");}
    {Fixture f;check(bn_seed_probe_begin(0,1,kLayoutHash,remove,9)==1);f.phases();check(f.originalAreas());
        // Authored observer-state input, not proof that this synthetic mask is
        // produced by the radius predicate. Only the fixture writes this array.
        f.field.areas[4]=0;blind_seed_probe_after_veto(f.field,production(0));Receipt r;
        check(r.read());check(r.observed==0&&r.vetoMatch==1);check(f.field.areas[4]==0);pass("valid-zero-mask-observed-not-applied");}
    {Fixture f;check(bn_seed_probe_begin(0,1,kLayoutHash,remove,9)==1);f.phases();
        blind_seed_probe_after_veto(f.field,production(0));Receipt r;check(!r.read());check(r.vetoMatch==0&&r.invalid==1);
        check(f.originalAreas());pass("expected-mask-cannot-erase-wrong-native-output");}
    {Fixture f;check(bn_seed_probe_begin(0,1,kLayoutHash,keep,9)==1);f.phases();auto bad=production();bad.stock_keep_count=2;
        blind_seed_probe_after_veto(f.field,bad);Receipt r;check(!r.read());check(f.originalAreas());pass("wrong-typed-receipt-refused");}
    {Fixture f;unsigned char wrong[32]={};check(bn_seed_probe_begin(0,1,wrong,keep,9)==1);f.phases();Receipt r;
        check(!r.read());check(r.invalid==1&&r.matched==0);check(f.originalAreas());pass("wrong-full-layout-hash-refused");}
    {Fixture f;unsigned char promotion[9]={1,0,0,0,1,0,0,0,0};check(bn_seed_probe_begin(0,1,kLayoutHash,promotion,9)==1);f.phases();Receipt r;
        check(!r.read());check(f.originalAreas());pass("expected-promotion-refused");}
    {Fixture f;check(bn_seed_probe_begin(0,1,kLayoutHash,keep,9)==1);blind_seed_probe_stock(f.field,f.distance,1,1);Receipt r;
        check(!r.read());for(int i=0;i<9;++i)check(f.field.areas[i]==63);pass("wrong-phase-never-mutates");}
    {Fixture f;check(bn_seed_probe_begin(0,1,kLayoutHash,keep,9)==1);f.field.cells[4].count=2;f.phases();Receipt r;
        check(!r.read());check(f.originalAreas());pass("multiple-spans-refused");}
    {Fixture f;check(bn_seed_probe_begin(0,1,kLayoutHash,keep,9)==1);f.field.spans[4].y=3;f.phases();Receipt r;
        check(!r.read());check(f.originalAreas());pass("unequal-height-refused");}
    {Fixture f;check(bn_seed_probe_begin(0,1,kLayoutHash,keep,9)==1);f.phases();f.field.spans[4].h=254;
        blind_seed_probe_after_veto(f.field,production());Receipt r;check(!r.read());check(f.originalAreas());pass("post-veto-topology-change-refused");}
    {Fixture f;check(bn_seed_probe_begin(0,1,kLayoutHash,keep,9)==1);f.phases();auto p=production();
        blind_seed_probe_after_veto(f.field,p);Receipt r;check(r.read());blind_seed_probe_after_veto(f.field,p);
        check(!r.read());check(f.originalAreas());pass("repeated-observation-refused");}
    {Fixture f;check(bn_seed_probe_begin(0,1,kLayoutHash,keep,9)==1);f.phases();auto bad=production();bad.work_bound=10000001;
        blind_seed_probe_after_veto(f.field,bad);Receipt r;check(!r.read());check(f.originalAreas());pass("invalid-work-bounds-refused");}
    {unsigned char bad[9]={2};
        check(bn_seed_probe_begin(-1,0,kLayoutHash,keep,9)==0);check(bn_seed_probe_begin(6,0,kLayoutHash,keep,9)==0);
        check(bn_seed_probe_begin(0,2,kLayoutHash,keep,9)==0);check(bn_seed_probe_begin(0,0,nullptr,keep,9)==0);
        check(bn_seed_probe_begin(0,0,kLayoutHash,nullptr,9)==0);check(bn_seed_probe_begin(0,0,kLayoutHash,keep,0)==0);
        check(bn_seed_probe_begin(0,0,kLayoutHash,keep,65537)==0);check(bn_seed_probe_begin(0,0,kLayoutHash,bad,9)==0);
        pass("invalid-begin-inputs-refused");}
    {bn_seed_probe_reset();Receipt r;check(!r.read());check(r.invalid==1&&r.vetoObserved==0&&r.matched==0);
        check(bn_seed_probe_receipt(nullptr,&r.original,&r.expected,&r.observed,&r.matched,&r.vetoObserved,&r.vetoMatch,&r.invalid)==0);
        pass("reset-and-null-output-refused");}
    std::printf("{\"schema\":1,\"scope\":\"read-only-seed-observer\",\"groups\":%d,\"checks\":%d,\"passed\":%d,\"physicalAuthority\":false}\n",groups,checks,checks);
}
