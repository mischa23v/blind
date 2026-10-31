#include "blind_detour.h"
#include <cmath>
#include <cstdio>
#include <cstring>
#include <limits>
extern "C" int bn_probe_association(void*,const float*,const float*,float*,int*);
static int checks=0;
static bool check(bool value,const char* label) {
    ++checks; if (!value) std::fprintf(stderr,"Strict C ABI failed: %s\n",label); return value;
}
#define CHECK(condition,label) do { if(!check((condition),(label))) return 1; } while(0)
int main() {
    const float vertices[]={-3,0,-3,-3,0,3,3,0,3,3,0,-3};
    const int triangles[]={0,1,2,0,2,3}; const unsigned char support[]={1,1};
    const BNConfig config={.225f,1.75f,.025f,.025f,.025f,15,250000,4096};
    void* h=bn_build_classified(vertices,4,triangles,2,&config,support);
    CHECK(h!=0,"real upstream classified plane build");
    struct Owner { void* h; ~Owner(){bn_destroy(h);} } owner={h};
    const float start[]={-1,-.05f,0},goal[]={1,-.05f,0},ext[]={.2f,.3f,.2f};
    float legacy[768]={},strict[768]={},ps[3]={},pg[3]={},sps[3]={},spg[3]={};
    unsigned int status=0,strictStatus=0;int complete=0,strictComplete=0;
    BNEndpointAssociation a={},b={};
    const int n=bn_path(h,start,goal,ext,legacy,256,ps,pg,&status,&complete);
    const int m=bn_path_strict(h,start,goal,ext,strict,256,sps,spg,&strictStatus,&strictComplete,&a,&b);
    CHECK(n>0 && n==m && complete && strictComplete,"accepted legacy/strict complete count");
    CHECK(status==strictStatus && std::memcmp(legacy,strict,n*3*sizeof(float))==0,"accepted route bits unchanged");
    CHECK(std::memcmp(ps,sps,sizeof(ps))==0 && std::memcmp(pg,spg,sizeof(pg))==0,"accepted projection bits unchanged");
    CHECK(a.found && b.found && a.is_over_polygon && b.is_over_polygon,"both supplied XZ endpoints over polygons");
    CHECK(ps[1]!=start[1],"vertical projection retained, not silently called identity");
    const float outside[]={2.8f,0,0},absent[]={20,0,0};
    CHECK(bn_path(h,start,outside,ext,legacy,256,ps,pg,&status,&complete)>0 && complete,"legacy outside goal comparator retained");
    for (float& value:strict) value=123.25f;
    status=99;complete=99;
    CHECK(bn_path_strict(h,start,outside,ext,strict,256,sps,spg,&status,&complete,&a,&b)==-1,"goal-only outside admission rejected");
    CHECK(status==0 && complete==0 && a.is_over_polygon && b.found && !b.is_over_polygon,"goal rejection receipt and route flags");
    bool unchanged=true;for(float value:strict) unchanged=unchanged && value==123.25f;
    CHECK(unchanged,"rejected admission emits no route points");
    CHECK(bn_path_strict(h,outside,goal,ext,strict,256,sps,spg,&status,&complete,&a,&b)==-1 && !a.is_over_polygon && b.is_over_polygon,"start-only outside rejected with BOTH receipts");
    CHECK(bn_path_strict(h,absent,goal,ext,strict,256,sps,spg,&status,&complete,&a,&b)==-1 && !a.found && b.is_over_polygon,"missing polygon still inspects other endpoint");
    CHECK(a.projected[0]==0 && a.projected[1]==0 && a.projected[2]==0,"absent projection deterministically zero");
    // The nearest boundary point is not assigned a guessed epsilon policy:
    // strict behavior must equal the released overload's exact on-edge answer.
    float edge[3]={};int over=0;
    CHECK(bn_probe_association(h,outside,ext,edge,&over)!=0,"obtain boundary point through upstream query");
    float projected[3]={};int edgeOver=0;
    CHECK(bn_probe_association(h,edge,ext,projected,&edgeOver)!=0,"upstream exact boundary association");
    const int edgeResult=bn_path_strict(h,edge,goal,ext,strict,256,sps,spg,&status,&complete,&a,&b);
    CHECK((edgeResult>=0)==(edgeOver!=0) && a.is_over_polygon==edgeOver,"on-edge rule exactly follows upstream");
    const float nanPoint[]={std::numeric_limits<float>::quiet_NaN(),0,0};
    const float zeroExtent[]={0,.3f,.2f},largeExtent[]={3.1f,.3f,.2f},negativeExtent[]={-.1f,.3f,.2f};
    for(int mode=0;mode<20;++mode) {
        std::memset(&a,0xa5,sizeof(a));std::memset(&b,0xa5,sizeof(b));status=99;complete=99;
        const float* queryExtents=mode==3?nanPoint:(mode==10?zeroExtent:(mode==11?largeExtent:(mode==12?negativeExtent:(mode==19?0:ext))));
        const int result=bn_path_strict(mode==0?0:h,mode==1?nanPoint:(mode==17?0:start),mode==2?nanPoint:(mode==18?0:goal),
            queryExtents,mode==4?0:strict,mode==5?1:(mode==6?4097:256),mode==13?0:sps,mode==14?0:spg,mode==15?0:&status,mode==16?0:&complete,
            mode==7?0:&a,mode==8?0:(mode==9?&a:&b));
        CHECK(result==-1 && status==(mode==15?99u:0u) && complete==(mode==16?99:0),"invalid input initialized available route refusal outputs");
        if(mode!=7) CHECK(a.found==0 && a.is_over_polygon==0 && a.status==0 && a.projected[0]==0 && a.projected[1]==0 && a.projected[2]==0,"invalid start receipt initialized");
        if(mode!=8 && mode!=9) CHECK(b.found==0 && b.is_over_polygon==0 && b.status==0 && b.projected[0]==0 && b.projected[1]==0 && b.projected[2]==0,"invalid goal receipt initialized");
    }
    std::printf("{\"schema\":1,\"scope\":\"strict-endpoint-cabi\",\"checks\":%d,\"passed\":%d,\"physicalAuthority\":false}\n",checks,checks);
    return 0;
}
