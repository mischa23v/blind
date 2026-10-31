// Source-only qualification harness. No geometry, routes, Recast tiles or app.
#include "candidate/seed_distance_maurer.h"
#include <algorithm>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>
using namespace research_maurer;
using B=std::vector<std::uint8_t>;
static U oracleWork=0,cases=0,checkedBits=0,distanceCells=0,tileRequests=0;
static void require(bool yes,const char* why){if(!yes)throw std::runtime_error(why);}
struct Grid {int w,h,r;B seed,stock,expected;};
struct Answer {B keep;std::vector<I> d;Receipt receipt;};
static Answer solve(const Grid& a,U limit=10000000,U extra=0){
    const std::size_t n=a.seed.size(),l=std::max(a.w,a.h);
    Answer o; B guardedKeep(n+2,0xa5);o.d.assign(n+2,1234567);
    std::vector<I> g(l+2,1234567),h(l+2,1234567);
    Buffers b{a.seed.data(),a.stock.data(),guardedKeep.data()+1,o.d.data()+1,g.data()+1,h.data()+1,n,n,l};
    const U capacityBytes=a.seed.capacity()+a.stock.capacity()+guardedKeep.capacity()+8ULL*(o.d.capacity()+g.capacity()+h.capacity());
    const U logicalBytes=11ULL*n+16ULL*l;
    require(capacityBytes>=logicalBytes,"capacity accounting");
    // Explicit bookkeeping reserve, not an allocator proof.
    require(transform(a.w,a.h,a.r,limit,extra+capacityBytes-logicalBytes+256,b,o.receipt)==Status::ok,"kernel refused admitted fixture");
    require(guardedKeep.front()==0xa5&&guardedKeep.back()==0xa5&&o.d.front()==1234567&&o.d.back()==1234567,"image canary");
    require(g.front()==1234567&&g.back()==1234567&&h.front()==1234567&&h.back()==1234567,"line canary");
    require(o.receipt.work<=o.receipt.bound&&o.receipt.bound<=limit,"work receipt");
    o.keep.assign(guardedKeep.begin()+1,guardedKeep.end()-1);o.d.erase(o.d.begin());o.d.pop_back();return o;
}
static B oracle(const Grid& a){
    B out=a.stock;
    for(int y=0;y<a.h;++y)for(int x=0;x<a.w;++x){
        const int i=x+y*a.w;if(!out[i])continue;bool keep=true;
        for(int dy=-a.r;dy<=a.r&&keep;++dy)for(int dx=-a.r;dx<=a.r;++dx){
            if(dx*dx+dy*dy>=a.r*a.r)continue;
            require(++oracleWork<=300000000ULL,"oracle fixed work cap");
            const int xx=x+dx,yy=y+dy;
            if(xx>=0&&yy>=0&&xx<a.w&&yy<a.h&&a.seed[xx+yy*a.w]){keep=false;break;}
        }out[i]=keep;
    }return out;
}
static U hash(const B& a){U h=14695981039346656037ULL;for(auto x:a){h^=x;h*=1099511628211ULL;}return h;}
static void distances(const Grid& a,const Answer& o){
    for(int y=0;y<a.h;++y)for(int x=0;x<a.w;++x){I best=infinity;
        for(int yy=0;yy<a.h;++yy)for(int xx=0;xx<a.w;++xx)if(a.seed[xx+yy*a.w]){
            const I dx=x-xx,dy=y-yy;best=std::min(best,dx*dx+dy*dy);
        }require(o.d[x+y*a.w]==best,"exact squared distance mismatch");++distanceCells;
    }
}
static U tiled(const Grid& a,const B& expected,int core,int shift){
    B out(a.seed.size(),0xa5),coverage(a.seed.size(),0);U work=0,bound=0;
    for(int cy=-shift;cy<a.h;cy+=core)for(int cx=-shift;cx<a.w;cx+=core){
        const int x0=std::max(0,cx),y0=std::max(0,cy),x1=std::min(a.w,cx+core),y1=std::min(a.h,cy+core);
        if(x0>=x1||y0>=y1)continue;
        const int hx0=std::max(0,x0-a.r),hy0=std::max(0,y0-a.r),hx1=std::min(a.w,x1+a.r),hy1=std::min(a.h,y1+a.r);
        Grid t{hx1-hx0,hy1-hy0,a.r,{},{},{}};t.seed.resize(t.w*t.h);t.stock.resize(t.w*t.h);
        for(int y=hy0;y<hy1;++y)for(int x=hx0;x<hx1;++x){const int j=x-hx0+(y-hy0)*t.w,i=x+y*a.w;t.seed[j]=a.seed[i];t.stock[j]=a.stock[i];}
        // Budget the COMPLETE request: each tile is not a fresh 10M allowance.
        const U tileBound=14ULL*t.seed.size();require(bound+tileBound<=10000000,"tile aggregate work bound");bound+=tileBound;
        auto v=solve(t,10000000-work,3ULL*a.seed.size());work+=v.receipt.work;
        for(int y=y0;y<y1;++y)for(int x=x0;x<x1;++x){const int i=x+y*a.w;require(!coverage[i],"overlapping output cores");coverage[i]=1;out[i]=v.keep[x-hx0+(y-hy0)*t.w];}
    }
    require(std::all_of(coverage.begin(),coverage.end(),[](unsigned char x){return x==1;}),"uncovered core");
    require(out==expected,"tile threshold mismatch");require(work<=bound,"tile work mismatch");++tileRequests;return work;
}
static void compare(const Grid& a,const std::string& name,bool exactDistances=false,bool verbose=true){
    require(a.w>0&&a.h>0&&a.seed.size()==static_cast<std::size_t>(a.w*a.h)&&a.stock.size()==a.seed.size(),"fixture size");
    const auto start=std::chrono::steady_clock::now();const B ref=oracle(a);const auto mid=std::chrono::steady_clock::now();
    const auto v=solve(a);const auto after=std::chrono::steady_clock::now();require(v.keep==ref,"whole threshold mismatch");
    if(!a.expected.empty())require(v.keep==a.expected,"frozen captured mask mismatch");
    for(std::size_t i=0;i<ref.size();++i)require(!v.keep[i]||a.stock[i],"promotion");
    if(exactDistances)distances(a,v);
    const int core=a.w>100?64:std::max(1,std::min(7,a.w/2));
    const U t1=tiled(a,ref,core,0),t2=tiled(a,ref,core,core/2);
    const auto end=std::chrono::steady_clock::now();++cases;checkedBits+=ref.size();
    U offsets=0;for(int dy=-a.r;dy<=a.r;++dy)for(int dx=-a.r;dx<=a.r;++dx)offsets+=(dx*dx+dy*dy<a.r*a.r);
    const U diskBound=offsets*std::count(a.stock.begin(),a.stock.end(),1);
    if(verbose)std::cout<<"CASE "<<name<<" cells="<<ref.size()<<" radius="<<a.r<<" keep="<<std::count(ref.begin(),ref.end(),1)
        <<" maskFNV64="<<hash(ref)<<" diskAdmissionBound="<<diskBound<<" wholeWork="<<v.receipt.work<<" tileWork="<<t1<<","<<t2
        <<" oracleUs="<<std::chrono::duration_cast<std::chrono::microseconds>(mid-start).count()
        <<" wholeUs="<<std::chrono::duration_cast<std::chrono::microseconds>(after-mid).count()
        <<" tiledPairUs="<<std::chrono::duration_cast<std::chrono::microseconds>(end-after).count()<<"\n";
}
static Grid blank(int w,int h,int r){return Grid{w,h,r,B(w*h,0),B(w*h,1),{}};}
static void captured(const char* path){
    std::ifstream f(path);require(bool(f),"fixture file");int count;f>>count;require(count==6,"six capture profiles");
    for(int p=0;p<count;++p){int w,h,n,r,real,stockCount,exactCount;f>>w>>h>>n>>r>>real>>stockCount>>exactCount;
        require(w>0&&h>0&&w*h<=250000&&n>0&&n<=65536&&r>0&&r<=80,"capture bounds");
        U words;for(int j=0;j<5;++j)f>>words; // preserved float32 words are not used in seed-distance calculation.
        std::vector<int> index(w*h),counts(w*h),area(n),stock(n),keep(n),con(4*n);
        for(int j=0;j<w*h;++j){f>>index[j]>>counts[j];require(counts[j]>=0&&counts[j]<=1&&index[j]>=0&&index[j]+counts[j]<=n,"capture topology");}
        int common=-1;for(int j=0;j<n;++j){int y,hh;f>>y>>hh>>area[j]>>stock[j]>>keep[j];
            if(common<0)common=y;require(y==common,"capture single flat layer");
            for(int d=0;d<4;++d)f>>con[4*j+d];
        }require(bool(f),"capture parse");
        Grid a=blank(w+2,h+2,r);std::fill(a.stock.begin(),a.stock.end(),0);a.expected.assign(a.seed.size(),0);
        for(int y=0;y<a.h;++y)for(int x=0;x<a.w;++x)if(!x||!y||x==a.w-1||y==a.h-1)a.seed[x+y*a.w]=1;
        const int dx[4]={-1,0,1,0},dy[4]={0,1,0,-1};int actualSeeds=0,actualStock=0,actualExact=0;
        for(int y=0;y<h;++y)for(int x=0;x<w;++x){int col=x+y*w;if(!counts[col])continue;const int i=index[col];bool seed=area[i]==0;
            for(int d=0;d<4;++d){if(con[4*i+d]<0){seed=true;continue;}const int nx=x+dx[d],ny=y+dy[d];
                require(nx>=0&&ny>=0&&nx<w&&ny<h&&counts[nx+ny*w]==1,"capture link");if(area[index[nx+ny*w]]==0)seed=true;}
            const int k=x+1+(y+1)*a.w;a.seed[k]=seed;a.stock[k]=stock[i]!=0;a.expected[k]=keep[i]!=0;
            actualSeeds+=seed;actualStock+=stock[i]!=0;actualExact+=keep[i]!=0;
        }require(actualSeeds==real&&actualStock==stockCount&&actualExact==exactCount,"capture counts");compare(a,"captured-"+std::to_string(p));
    }std::string trailing;require(!(f>>trailing),"capture trailing input");
}
static void refusals(){
    auto a=blank(5,5,3);B out(25,0xa5);std::vector<I>d(25),g(5),h(5);Receipt rr;
    Buffers b{a.seed.data(),a.stock.data(),out.data(),d.data(),g.data(),h.data(),25,25,5};
    auto check=[&](Status s,Status expected){require(s==expected,"refusal code");require(std::all_of(out.begin(),out.end(),[](unsigned char x){return x==0xa5;}),"refusal changed output");};
    check(transform(0,5,3,10000000,0,b,rr),Status::invalid);
    check(transform(5,5,0,10000000,0,b,rr),Status::invalid);
    check(transform(5,5,81,10000000,0,b,rr),Status::invalid);
    check(transform(5,5,3,10000001,0,b,rr),Status::work_limit);
    check(transform(5,5,3,349,0,b,rr),Status::work_limit);
    check(transform(5,5,3,10000000,2097152,b,rr),Status::memory_limit);
    b.lineCapacity=4;check(transform(5,5,3,10000000,0,b,rr),Status::capacity);b.lineCapacity=5;
    b.distanceCapacity=24;check(transform(5,5,3,10000000,0,b,rr),Status::capacity);b.distanceCapacity=25;
    b.maskCapacity=24;check(transform(5,5,3,10000000,0,b,rr),Status::capacity);b.maskCapacity=25;
    a.seed[8]=2;check(transform(5,5,3,10000000,0,b,rr),Status::invalid);a.seed[8]=0;
    require(transform(5,5,3,350,2097152-(11*25+16*5),b,rr)==Status::ok,"exact limits");
    std::cout<<"REFUSALS 10 plus exact work/memory boundary passed\n";
}
int main(int argc,char**argv){try{
    require(argc==2,"one frozen capture input");captured(argv[1]);
    for(int bits=0;bits<512;++bits)for(int r=1;r<=4;++r)for(int pattern=0;pattern<2;++pattern){auto a=blank(3,3,r);
        for(int i=0;i<9;++i){a.seed[i]=(bits>>i)&1;a.stock[i]=pattern?(i%2==0):1;}compare(a,"exhaustive",true,false);}
    for(int kind=0;kind<8;++kind){auto a=blank(kind==0?1:33,kind==1?1:31,kind==2?80:5);
        for(int y=0;y<a.h;++y)for(int x=0;x<a.w;++x){const int i=x+y*a.w;
            a.seed[i]=kind==3 || (kind==4?(x+y)%2==0:kind==5?(x==7||y==7):kind==6?(x==16&&y==15):kind==7?(x>=12&&x<=20&&y>=10&&y<=20):false);
            if(kind==2)a.stock[i]=(x==16&&y==15);}
        compare(a,"authored-"+std::to_string(kind),a.seed.size()<=1100);}
    // Radius equality witness: (3,4) is exactly R=5; (0,4) is inside, (4,4) outside.
    {auto a=blank(17,17,5);a.seed[8+8*17]=1;auto v=solve(a);require(v.keep[11+12*17]&& !v.keep[8+12*17]&&v.keep[12+12*17],"strict radius equality");compare(a,"radius-equality",true);}
    // 5m/6m authored 2cm grids: no real-room capture or navigation claim.
    for(int side:{252,302}){auto a=blank(side,side,15);for(int y=0;y<side;++y)for(int x=0;x<side;++x){const int i=x+y*side;
        a.seed[i]=!x||!y||x==side-1||y==side-1||(x==64&&y>=61&&y<=67)||(x==128&&y==128);
        a.stock[i]=(x>=15&&y>=15&&x<side-15&&y<side-15);}
        compare(a,"authored-scale-"+std::to_string(side));}
    refusals();require(cases==4113,"fixed case count");require(tileRequests==2*cases,"fixed tile request count");
    std::cout<<"TOTAL cases="<<cases<<" tileRequests="<<tileRequests<<" checkedBits="<<checkedBits<<" exactDistanceCells="<<distanceCells<<" oracleWork="<<oracleWork<<" PASS\n";return 0;
}catch(const std::exception&e){std::cerr<<"FAIL "<<e.what()<<"\n";return 1;}}
