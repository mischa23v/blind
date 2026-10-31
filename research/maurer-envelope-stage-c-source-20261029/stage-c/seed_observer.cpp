// Read-only scratch observations. Never writes areas, geometry or route policy.
// Not included in any production target. Expected masks are test oracles only.
// CommonCrypto SHA256 is Apple's documented implementation, not a custom hash.
#include "seed_probe.h"
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
struct ProbeState {
    bool active=false,invalid=false,layoutMatch=false,vetoObserved=false,vetoMatch=false;
    int profile=-1,expectVeto=0,observedVetoKeep=0,count=0,phases=0,width=0,height=0,radius=0,originalKeep=0,candidateKeep=0;
    std::array<unsigned char,32> expected={},actual={};
    std::array<uint32_t,3> origin={};uint32_t cs=0,ch=0;
    std::vector<unsigned char> keep;
    std::vector<std::array<int,2>> columns;
    std::vector<std::array<int,12>> spans;
};
static thread_local ProbeState state;
extern "C" void bn_seed_probe_reset(){state=ProbeState();}
extern "C" int bn_seed_probe_begin(int profile,int expectVeto,const unsigned char* hash,const unsigned char* keep,int count) {
    bn_seed_probe_reset();
    if(profile<0 || profile>=6 || (expectVeto!=0 && expectVeto!=1) || !hash || !keep || count<1 || count>65536){state.invalid=true;return 0;}
    for(int i=0;i<count;++i)if(keep[i]>1){state.invalid=true;return 0;}
    state.active=true;state.profile=profile;state.expectVeto=expectVeto;state.count=count;
    std::memcpy(state.expected.data(),hash,32);state.keep.assign(keep,keep+count);return 1;
}
static void appendWord(std::vector<unsigned char>& bytes,uint32_t w) {
    for(int shift=0;shift<32;shift+=8)bytes.push_back(static_cast<unsigned char>((w>>shift)&255u));
}
static void digestLayout(ProbeState& t) {
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
extern "C" void blind_seed_probe_stock(const rcCompactHeightfield& c,const unsigned char* distance,int radius,int phase) {
    ProbeState& t=state;
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
    // Completed stock-layout hash is evidence only; NEVER writes areas.
}
extern "C" void blind_seed_probe_after_veto(const rcCompactHeightfield& c,const BNSeedRadiusVetoReceipt& receipt) {
    ProbeState& t=state;
    if(!t.active || t.invalid)return;
    if(!t.expectVeto || t.vetoObserved || t.phases!=2 || !t.layoutMatch){t.invalid=true;return;}
    t.vetoObserved=true;
    if(!c.cells || !c.spans || !c.areas || c.width!=t.width || c.height!=t.height || c.spanCount!=t.count ||
       word(c.cs)!=t.cs || word(c.ch)!=t.ch || t.columns.size()!=size_t(c.width*c.height) ||
       t.spans.size()!=size_t(t.count) || receipt.schema!=1 || receipt.status!=BN_SEED_RADIUS_APPLIED ||
       receipt.width!=t.width || receipt.height!=t.height || receipt.span_count!=t.count ||
       receipt.radius_cells!=t.radius || receipt.common_y_voxel!=t.spans[0][3] ||
       receipt.stock_keep_count!=t.originalKeep || receipt.exact_keep_count!=t.candidateKeep ||
       receipt.additional_rejected_count!=t.originalKeep-t.candidateKeep ||
       receipt.work_limit!=10000000ULL || receipt.work_performed>receipt.work_bound || receipt.work_bound>receipt.work_limit) {
        t.invalid=true;return;
    }
    int realSeeds=0;for(const auto& row:t.spans)realSeeds+=row[7]==0;
    if(receipt.real_seed_count!=realSeeds || receipt.exterior_seed_count!=2*(t.width+t.height+2)){t.invalid=true;return;}
    for(int j=0;j<3;++j)if(word(c.bmin[j])!=t.origin[j]){t.invalid=true;return;}
    int cursor=0;
    for(int z=0;z<c.height;++z)for(int x=0;x<c.width;++x){
        const auto& cell=c.cells[x+z*c.width];const auto& saved=t.columns[x+z*c.width];
        if(cell.count>1 || int(cell.index)!=saved[0] || int(cell.count)!=saved[1]){t.invalid=true;return;}
        if(!cell.count)continue;
        const int i=int(cell.index);if(i!=cursor++ || i<0 || i>=t.count){t.invalid=true;return;}
        const auto& row=t.spans[i];const auto& span=c.spans[i];
        if(int(span.y)!=row[3] || int(span.h)!=row[4]){t.invalid=true;return;}
        for(int d=0;d<4;++d){
            const int connection=rcGetCon(span,d);
            if(row[8+d]<0){if(connection!=RC_NOT_CONNECTED){t.invalid=true;return;}}
            else{
                const int nx=x+rcGetDirOffsetX(d),nz=z+rcGetDirOffsetY(d);
                if(connection!=0 || nx<0 || nx>=c.width || nz<0 || nz>=c.height ||
                   c.cells[nx+nz*c.width].count!=1 || int(c.cells[nx+nz*c.width].index)!=row[8+d]){t.invalid=true;return;}
            }
        }
        const unsigned char wanted=t.keep[i]?static_cast<unsigned char>(row[6]):RC_NULL_AREA;
        if(c.areas[i]!=wanted){t.invalid=true;return;}
        t.observedVetoKeep+=c.areas[i]!=RC_NULL_AREA;
    }
    if(cursor!=t.count || t.observedVetoKeep!=t.candidateKeep){t.invalid=true;return;}
    t.vetoMatch=true;
}
extern "C" void blind_seed_probe_after_envelope(const rcCompactHeightfield& c,const BNSeedRadiusEnvelopeReceipt& receipt) {
    ProbeState& t=state;
    if(!t.active || t.invalid)return;
    if(!t.expectVeto || t.vetoObserved || t.phases!=2 || !t.layoutMatch){t.invalid=true;return;}
    t.vetoObserved=true;
    if(!c.cells || !c.spans || !c.areas || c.width!=t.width || c.height!=t.height || c.spanCount!=t.count ||
       word(c.cs)!=t.cs || word(c.ch)!=t.ch || t.columns.size()!=size_t(c.width*c.height) ||
       t.spans.size()!=size_t(t.count) || receipt.schema!=2 || receipt.algorithm!=BN_ENVELOPE_MAURER_INT64_V1 || receipt.work_unit!=BN_ENVELOPE_LOOP_VISIT_OR_COMPARISON_V1 || receipt.status!=BN_SEED_RADIUS_APPLIED ||
       receipt.width!=t.width || receipt.height!=t.height || receipt.span_count!=t.count ||
       receipt.radius_cells!=t.radius || receipt.common_y_voxel!=t.spans[0][3] ||
       receipt.stock_keep_count!=t.originalKeep || receipt.exact_keep_count!=t.candidateKeep ||
       receipt.additional_rejected_count!=t.originalKeep-t.candidateKeep ||
       receipt.padded_cell_count!=static_cast<unsigned long long>(t.width+2)*(t.height+2) ||
       receipt.work_bound!=14ULL*receipt.padded_cell_count || receipt.workspace_bytes_declared>2ULL*1024*1024 ||
       receipt.workspace_bytes_declared!=11ULL*receipt.padded_cell_count+16ULL*((t.width>t.height?t.width:t.height)+2)+t.count+448ULL ||
       receipt.work_limit!=10000000ULL || receipt.work_performed>receipt.work_bound || receipt.work_bound>receipt.work_limit) {
        t.invalid=true;return;
    }
    int realSeeds=0;for(const auto& row:t.spans)realSeeds+=row[7]==0;
    if(receipt.real_seed_count!=realSeeds || receipt.exterior_seed_count!=2*(t.width+t.height+2)){t.invalid=true;return;}
    for(int j=0;j<3;++j)if(word(c.bmin[j])!=t.origin[j]){t.invalid=true;return;}
    int cursor=0;
    for(int z=0;z<c.height;++z)for(int x=0;x<c.width;++x){
        const auto& cell=c.cells[x+z*c.width];const auto& saved=t.columns[x+z*c.width];
        if(cell.count>1 || int(cell.index)!=saved[0] || int(cell.count)!=saved[1]){t.invalid=true;return;}
        if(!cell.count)continue;
        const int i=int(cell.index);if(i!=cursor++ || i<0 || i>=t.count){t.invalid=true;return;}
        const auto& row=t.spans[i];const auto& span=c.spans[i];
        if(int(span.y)!=row[3] || int(span.h)!=row[4]){t.invalid=true;return;}
        for(int d=0;d<4;++d){
            const int connection=rcGetCon(span,d);
            if(row[8+d]<0){if(connection!=RC_NOT_CONNECTED){t.invalid=true;return;}}
            else{
                const int nx=x+rcGetDirOffsetX(d),nz=z+rcGetDirOffsetY(d);
                if(connection!=0 || nx<0 || nx>=c.width || nz<0 || nz>=c.height ||
                   c.cells[nx+nz*c.width].count!=1 || int(c.cells[nx+nz*c.width].index)!=row[8+d]){t.invalid=true;return;}
            }
        }
        const unsigned char wanted=t.keep[i]?static_cast<unsigned char>(row[6]):RC_NULL_AREA;
        if(c.areas[i]!=wanted){t.invalid=true;return;}
        t.observedVetoKeep+=c.areas[i]!=RC_NULL_AREA;
    }
    if(cursor!=t.count || t.observedVetoKeep!=t.candidateKeep){t.invalid=true;return;}
    t.vetoMatch=true;
}
extern "C" int bn_seed_probe_receipt(unsigned char* actual,int* original,int* expected,
    int* observed,int* matched,int* vetoObserved,int* vetoMatch,int* invalid) {
    const bool valid=state.active&&!state.invalid&&state.phases==2&&state.layoutMatch&&
        (state.expectVeto ? state.vetoObserved&&state.vetoMatch : !state.vetoObserved);
    if(actual)std::memcpy(actual,state.actual.data(),32);
    if(original)*original=state.originalKeep;if(expected)*expected=state.candidateKeep;
    if(observed)*observed=state.observedVetoKeep;if(matched)*matched=state.layoutMatch?1:0;
    if(vetoObserved)*vetoObserved=state.vetoObserved?1:0;if(vetoMatch)*vetoMatch=state.vetoMatch?1:0;
    if(invalid)*invalid=valid?0:1;
    if(!actual || !original || !expected || !observed || !matched || !vetoObserved || !vetoMatch || !invalid)return 0;
    return valid?1:0;
}
