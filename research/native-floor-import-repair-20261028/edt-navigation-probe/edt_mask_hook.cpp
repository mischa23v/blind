// Diagnostic scratch-only exclusion hook. Not included in any production target.
// CommonCrypto SHA256 is Apple's documented implementation, not a custom hash.
#include "edt_probe.h"
#include "Recast.h"
#include <CommonCrypto/CommonDigest.h>
#include <array>
#include <cstdint>
#include <cstring>
#include <initializer_list>
#include <limits>
#include <vector>
static_assert(sizeof(float)==4 && std::numeric_limits<float>::is_iec559,"Float32 required");
static_assert(CC_SHA256_DIGEST_LENGTH==32,"SHA256 receipt size");
static uint32_t word(float v){uint32_t b;std::memcpy(&b,&v,4);return b;}
struct EDTState {
    bool active=false,invalid=false,layoutMatch=false,applied=false;
    int profile=-1,mode=0,count=0,phases=0,width=0,height=0,radius=0,originalKeep=0,candidateKeep=0;
    std::array<unsigned char,32> expected={},actual={};
    std::array<uint32_t,3> origin={};uint32_t cs=0,ch=0;
    std::vector<unsigned char> keep;
    std::vector<std::array<int,2>> columns;
    std::vector<std::array<int,12>> spans;
};
static thread_local EDTState state;
extern "C" void bn_edt_reset(){state=EDTState();}
extern "C" int bn_edt_begin(int profile,int mode,const unsigned char* hash,const unsigned char* keep,int count) {
    bn_edt_reset();
    if(profile<0 || profile>=6 || (mode!=0 && mode!=1) || !hash || !keep || count<1 || count>65536){state.invalid=true;return 0;}
    for(int i=0;i<count;++i)if(keep[i]>1){state.invalid=true;return 0;}
    state.active=true;state.profile=profile;state.mode=mode;state.count=count;
    std::memcpy(state.expected.data(),hash,32);state.keep.assign(keep,keep+count);return 1;
}
static void appendWord(std::vector<unsigned char>& bytes,uint32_t w) {
    for(int shift=0;shift<32;shift+=8)bytes.push_back(static_cast<unsigned char>((w>>shift)&255u));
}
static void digestLayout(EDTState& t) {
    const size_t words=12+t.columns.size()*2+t.spans.size()*12;
    if(words>16u*1024u*1024u/4u){t.invalid=true;return;}
    std::vector<unsigned char> bytes;bytes.reserve(words*4);
    for(uint32_t w:{0x424c4544u,1u,uint32_t(t.profile),uint32_t(t.width),uint32_t(t.height),uint32_t(t.count),
                   uint32_t(t.radius),t.cs,t.ch,t.origin[0],t.origin[1],t.origin[2]})appendWord(bytes,w);
    for(const auto& row:t.columns)for(int v:row)appendWord(bytes,static_cast<uint32_t>(v));
    for(const auto& row:t.spans)for(int v:row)appendWord(bytes,static_cast<uint32_t>(v));
    if(bytes.size()!=words*4 || CC_SHA256(bytes.data(),static_cast<CC_LONG>(bytes.size()),t.actual.data())!=t.actual.data()){t.invalid=true;return;}
    t.layoutMatch=t.actual==t.expected;
    if(!t.layoutMatch)t.invalid=true;
}
// Inserted into a scratch copy of RecastArea only: phase0 after its original
// distance computation, phase1 after its original erosion threshold, before free.
extern "C" void blind_edt_mask_hook(rcCompactHeightfield& c,const unsigned char* distance,int radius,int phase) {
    EDTState& t=state;
    if(!t.active || t.invalid)return;
    if(!distance || phase!=t.phases || phase>1){t.invalid=true;return;}++t.phases;
    if(!c.cells || !c.spans || !c.areas || c.width<1 || c.height<1 || (long long)c.width*c.height>250000 || c.spanCount!=t.count || radius<1 || radius>80){t.invalid=true;return;}
    if(phase==0) {
        t.width=c.width;t.height=c.height;t.radius=radius;t.cs=word(c.cs);t.ch=word(c.ch);
        for(int i=0;i<3;++i)t.origin[i]=word(c.bmin[i]);
        t.columns.reserve(c.width*c.height);t.spans.reserve(c.spanCount);
    } else {
        if(t.width!=c.width || t.height!=c.height || t.radius!=radius || t.cs!=word(c.cs) || t.ch!=word(c.ch) ||
           t.columns.size()!=size_t(c.width*c.height) || t.spans.size()!=size_t(c.spanCount)){t.invalid=true;return;}
        for(int i=0;i<3;++i)if(t.origin[i]!=word(c.bmin[i])){t.invalid=true;return;}
    }
    int cursor=0,commonY=-1;
    for(int z=0;z<c.height;++z)for(int x=0;x<c.width;++x) {
        const rcCompactCell& cell=c.cells[x+z*c.width];
        if(cell.count>1 || (unsigned long long)cell.index+cell.count>(unsigned)c.spanCount){t.invalid=true;return;}
        const std::array<int,2> column={{int(cell.index),int(cell.count)}};
        if(phase==0)t.columns.push_back(column);
        else if(t.columns[x+z*c.width]!=column){t.invalid=true;return;}
        for(int i=int(cell.index),end=int(cell.index+cell.count);i<end;++i) {
            if(i!=cursor || cursor>=t.count){t.invalid=true;return;}
            const rcCompactSpan& span=c.spans[i];
            if(commonY<0)commonY=span.y;else if(commonY!=int(span.y)){t.invalid=true;return;}
            std::array<int,12> row={{i,x,z,int(span.y),int(span.h),c.areas[i],-1,distance[i],-1,-1,-1,-1}};
            bool seed=c.areas[i]==RC_NULL_AREA;
            for(int d=0;d<4;++d) {
                const int connection=rcGetCon(span,d);
                if(connection==RC_NOT_CONNECTED){seed=true;continue;}
                const int nx=x+rcGetDirOffsetX(d),nz=z+rcGetDirOffsetY(d);
                if(nx<0 || nx>=c.width || nz<0 || nz>=c.height){t.invalid=true;return;}
                const rcCompactCell& nc=c.cells[nx+nz*c.width];
                if(connection>=int(nc.count) || nc.count!=1 || (unsigned long long)nc.index+nc.count>(unsigned)c.spanCount){t.invalid=true;return;}
                const int neighbor=int(nc.index)+connection;
                const rcCompactSpan& ns=c.spans[neighbor];
                const int opposite=rcGetCon(ns,(d+2)%4);
                if(ns.y!=span.y || opposite==RC_NOT_CONNECTED || int(cell.index)+opposite!=i){t.invalid=true;return;}
                row[8+d]=neighbor;
                if(c.areas[neighbor]==RC_NULL_AREA)seed=true;
            }
            if(phase==0) {
                if((distance[i]==0)!=seed){t.invalid=true;return;}
                t.spans.push_back(row);
            } else {
                auto& before=t.spans[cursor];
                for(int k=0;k<12;++k)if(k!=5 && k!=6 && before[k]!=row[k]){t.invalid=true;return;}
                before[6]=c.areas[i];
                if(before[6]!=(before[7]<radius*2 ? RC_NULL_AREA:before[5])){t.invalid=true;return;}
                if(t.keep[i] && c.areas[i]==RC_NULL_AREA){t.invalid=true;return;} // Never restore a removed span.
                t.originalKeep+=c.areas[i]!=RC_NULL_AREA;t.candidateKeep+=t.keep[i]!=0;
            }
            ++cursor;
        }
    }
    if(cursor!=t.count){t.invalid=true;return;}
    if(phase==0)return;
    digestLayout(t);
    if(t.invalid || !t.layoutMatch)return; // No mask application before full hash validation.
    if(t.mode==1) {
        for(int i=0;i<t.count;++i)if(!t.keep[i])c.areas[i]=RC_NULL_AREA;
        t.applied=true;
    }
}
extern "C" int bn_edt_receipt(unsigned char* actual,int* original,int* candidate,int* applied,int* matched,int* invalid) {
    if(actual)std::memcpy(actual,state.actual.data(),32);
    if(original)*original=state.originalKeep;if(candidate)*candidate=state.candidateKeep;
    if(applied)*applied=state.applied?1:0;if(matched)*matched=state.layoutMatch?1:0;
    if(invalid)*invalid=(!state.active || state.invalid || state.phases!=2)?1:0;
    if(!actual || !original || !candidate || !applied || !matched || !invalid)return 0;
    return state.active&&!state.invalid&&state.phases==2&&state.layoutMatch?1:0;
}
