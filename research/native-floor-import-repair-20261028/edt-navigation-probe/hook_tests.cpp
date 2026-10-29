// Native tests of the scratch hook only; no planner/physical clearance claim.
#include "edt_probe.h"
#include "Recast.h"
#include "RecastAlloc.h"
#include "hook_test_digest.hpp"
#include <cstdio>
#include <cstdlib>
#include <cstring>
extern "C" void blind_edt_mask_hook(rcCompactHeightfield&,const unsigned char*,int,int);
static int checks=0;
static void check(bool yes){if(!yes){std::fprintf(stderr,"scratch EDT hook check %d failed\n",checks+1);std::abort();}++checks;}
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
    void phases(){blind_edt_mask_hook(field,distance,1,0);originalErosion();blind_edt_mask_hook(field,distance,1,1);}
};
struct Receipt {
    unsigned char digest[32]={};int original=-1,candidate=-1,applied=-1,matched=-1,invalid=-1;
    bool read(){return bn_edt_receipt(digest,&original,&candidate,&applied,&matched,&invalid)!=0;}
};
int main(){
    const unsigned char keep[9]={0,0,0,0,1,0,0,0,0},remove[9]={};
    for(int mode=0;mode<2;++mode){
        Fixture f;check(bn_edt_begin(0,mode,kLayoutHash,keep,9)==1);f.phases();Receipt r;
        check(r.read());check(r.original==1&&r.candidate==1);check(r.applied==mode&&r.matched==1&&r.invalid==0);
        check(std::memcmp(r.digest,kLayoutHash,32)==0);check(f.originalAreas());bn_edt_reset();
    }
    {Fixture f;check(bn_edt_begin(0,1,kLayoutHash,remove,9)==1);f.phases();Receipt r;check(r.read());check(r.original==1&&r.candidate==0&&r.applied==1);check(f.field.areas[4]==0);bn_edt_reset();}
    {Fixture f;check(bn_edt_begin(0,0,kLayoutHash,remove,9)==1);f.phases();Receipt r;check(r.read());check(r.original==1&&r.candidate==0&&r.applied==0);check(f.originalAreas());bn_edt_reset();}
    {Fixture f;unsigned char wrong[32]={};check(bn_edt_begin(0,1,wrong,remove,9)==1);f.phases();Receipt r;check(!r.read());check(r.invalid==1&&r.matched==0&&r.applied==0);check(f.originalAreas());bn_edt_reset();}
    {Fixture f;unsigned char promotion[9]={1,0,0,0,1,0,0,0,0};check(bn_edt_begin(0,1,kLayoutHash,promotion,9)==1);f.phases();Receipt r;check(!r.read());check(r.invalid==1&&r.applied==0);check(f.originalAreas());bn_edt_reset();}
    {Fixture f;check(bn_edt_begin(0,1,kLayoutHash,remove,9)==1);blind_edt_mask_hook(f.field,f.distance,1,1);Receipt r;check(!r.read());check(r.invalid==1&&r.applied==0);check(f.field.areas[4]==63);bn_edt_reset();}
    {Fixture f;check(bn_edt_begin(0,1,kLayoutHash,remove,9)==1);f.field.cells[4].count=2;f.phases();Receipt r;check(!r.read());check(r.invalid==1&&r.applied==0);check(f.originalAreas());bn_edt_reset();}
    {Fixture f;check(bn_edt_begin(0,1,kLayoutHash,remove,9)==1);f.field.spans[4].y=3;f.phases();Receipt r;check(!r.read());check(r.invalid==1&&r.applied==0);check(f.originalAreas());bn_edt_reset();}
    unsigned char badMask[9]={2};
    check(bn_edt_begin(-1,0,kLayoutHash,keep,9)==0);check(bn_edt_begin(6,0,kLayoutHash,keep,9)==0);
    check(bn_edt_begin(0,2,kLayoutHash,keep,9)==0);check(bn_edt_begin(0,0,nullptr,keep,9)==0);
    check(bn_edt_begin(0,0,kLayoutHash,nullptr,9)==0);check(bn_edt_begin(0,0,kLayoutHash,keep,0)==0);
    check(bn_edt_begin(0,0,kLayoutHash,keep,65537)==0);check(bn_edt_begin(0,0,kLayoutHash,badMask,9)==0);
    bn_edt_reset();Receipt r;check(!r.read());check(r.invalid==1&&r.applied==0&&r.matched==0);
    check(bn_edt_receipt(nullptr,&r.original,&r.candidate,&r.applied,&r.matched,&r.invalid)==0);
    std::printf("{\"schema\":1,\"scope\":\"scratch-edt-hook\",\"checks\":%d,\"passed\":%d,\"physicalAuthority\":false}\n",checks,checks);
}
