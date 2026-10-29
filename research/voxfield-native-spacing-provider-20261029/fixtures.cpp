// Synthetic provider contracts only. No mapper, files, measured scene, or gain gate.
// N2/N3 providers carry their own source derivation and BSD attribution.
#include "n3_adapter.h"
#include "../n2-normal-candidate/n2_adapter.h"
#include <algorithm>
#include <iostream>
#include <iomanip>
#include <string>
#include <numeric>
#include <utility>
using R=n2::Reason;
static void require(bool x,const char* m){if(!x)throw std::runtime_error(m);}
static n2::Raster raster(int w=32,int h=24,int mm=2000){
 n2::Raster f;f.width=w;f.height=h;f.fx=f.fy=810.82548516100394;
 f.cx=(w-1)*.5;f.cy=(h-1)*.5;f.depthMm.assign(size_t(w)*h,uint16_t(mm));return f;
}
static size_t at(const n2::Raster& f,int x,int y){return size_t(y)*f.width+x;}
static R reasonAt(const n2::Result& r,size_t p){
 auto it=std::lower_bound(r.pixelIndices.begin(),r.pixelIndices.end(),p);
 require(it!=r.pixelIndices.end()&&*it==p,"point disappeared");
 return r.reasons[size_t(it-r.pixelIndices.begin())];
}
// Diagnostic normalization removes float unit-length dot error; differs from
// earlier raw-float-dot angle floor. No provider normal is changed.
static double angle(const n2::Vec& a,const Eigen::Vector3d& b){
 return std::acos(std::max(-1.,std::min(1.,a.cast<double>().normalized().dot(b.normalized()))))*180./std::acos(-1.);
}
static void report(const std::string& name,const char* arm,const n2::Result& r,const Eigen::Vector3d* truth){
 size_t axis=0;double sum=0,mx=0;
 for(size_t i=0;i<r.points.size();++i){
  if(r.reasons[i]!=R::Valid){require(r.normals[i].isZero(0),"unavailable normal not zero");continue;}
  require(r.normals[i].allFinite()&&std::abs(r.normals[i].norm()-1)<1e-6,"invalid unit normal");
  if(r.normals[i]==n2::Vec(0,0,1))++axis;
  if(truth){double a=angle(r.normals[i],*truth);sum+=a;mx=std::max(mx,a);}
 }
 const auto valid=r.counts[0];
 std::cout<<"{\"fixture\":\""<<name<<"\",\"arm\":\""<<arm<<"\",\"points\":"<<r.points.size()<<",\"zero_depth\":"<<r.zero<<",\"far_depth\":"<<r.far<<",\"reasons\":[";
 for(size_t j=0;j<r.counts.size();++j)std::cout<<(j?",":"")<<r.counts[j];
 std::cout<<"],\"exact_plus_z\":"<<axis<<",\"angle_mean_deg\":";
 if(truth&&valid)std::cout<<sum/valid;else std::cout<<"null";
 std::cout<<",\"angle_max_deg\":";if(truth&&valid)std::cout<<mx;else std::cout<<"null";
 std::cout<<"}\n";
}
static void compare(const std::string& name,const n2::Raster& f,const Eigen::Vector3d* truth=nullptr){
 const auto a=n2::compute(f),b=n3::compute(f);
 require(a.pixelIndices==b.pixelIndices,"point order changed");
 require(a.zero==b.zero&&a.far==b.far,"admission changed");
 require(a.points.size()==b.points.size(),"point count changed");
 for(size_t i=0;i<a.points.size();++i)require(a.points[i]==b.points[i],"point coordinates changed");
 for(const auto* r:{&a,&b}){
  require(std::accumulate(r->counts.begin(),r->counts.end(),size_t(0))==r->points.size(),"reason accounting");
  require(r->points.size()+r->zero+r->far==f.depthMm.size(),"raster accounting");
 }
 // Widened stencil boundary changes normal availability, never point retention.
 size_t expectedBoundary=0;
 for(int y=0;y<f.height;++y)for(int x=0;x<f.width;++x)
  if(n2::admitted(f.depthMm[at(f,x,y)])&&(x+4>=f.width||y+4>=f.height)){
   ++expectedBoundary;require(reasonAt(b,at(f,x,y))==R::Boundary,"N3 widened border");
  }
 require(b.counts[unsigned(R::Boundary)]==expectedBoundary,"N3 extra boundary");
 report(name,"N2",a,truth);report(name,"N3",b,truth);
 if(truth){size_t count=0;double sumA=0,sumB=0,maxA=0,maxB=0;
  for(size_t i=0;i<a.points.size();++i){size_t pixel=a.pixelIndices[i];
   int x=int(pixel%size_t(f.width)),y=int(pixel/size_t(f.width));
   if(x+4>=f.width||y+4>=f.height||a.reasons[i]!=R::Valid||b.reasons[i]!=R::Valid)continue;
   double aa=angle(a.normals[i],*truth),ab=angle(b.normals[i],*truth);
   ++count;sumA+=aa;sumB+=ab;maxA=std::max(maxA,aa);maxB=std::max(maxB,ab);
  }
  std::cout<<"{\"fixture\":\""<<name<<"\",\"domain\":\"common_interior_valid_both\",\"count\":"<<count<<",\"N2_mean_deg\":";
  if(count)std::cout<<sumA/count;else std::cout<<"null";
  std::cout<<",\"N3_mean_deg\":";if(count)std::cout<<sumB/count;else std::cout<<"null";
  std::cout<<",\"N2_max_deg\":";if(count)std::cout<<maxA;else std::cout<<"null";
  std::cout<<",\"N3_max_deg\":";if(count)std::cout<<maxB;else std::cout<<"null";
  std::cout<<"}\n";
 }
}
static double planeZ(int x,int y,const n2::Raster& f,double intercept=2.){return intercept/(1.+.4*(x-f.cx)/f.fx+.3*(y-f.cy)/f.fy);}
static n2::Vec idealPoint(int x,int y,const n2::Raster& f,double intercept){double z=planeZ(x,y,f,intercept);return n2::Vec(float((x-f.cx)*z/f.fx),float((y-f.cy)*z/f.fy),float(z));}
static void ideal(){
 const auto f=raster(64,64);const Eigen::Vector3d truth(.4,.3,1);
 // Same shared numerical helper, ideal float points; NOT integer-raster compute.
 for(double intercept:{.3,1.,2.,3.})for(int spacing:{1,4})for(bool common:{false,true}){double sum=0,mx=0;size_t n=0;
  for(int y=0;y+(common?4:spacing)<f.height;++y)for(int x=0;x+(common?4:spacing)<f.width;++x){
   n2::Vec normal;require(n2::tripletNormal(idealPoint(x,y,f,intercept),idealPoint(x+spacing,y,f,intercept),idealPoint(x,y+spacing,f,intercept),&normal)==R::Valid,"ideal plane invalid");
   double a=angle(normal,truth);sum+=a;mx=std::max(mx,a);++n;
  }
  std::cout<<"{\"fixture\":\"ideal_float_shared_helper\",\"spacing\":"<<spacing<<",\"domain\":\""<<(common?"common_interior":"own_support")<<"\",\"intercept_m\":"<<intercept<<",\"valid\":"<<n<<",\"angle_mean_deg\":"<<sum/n<<",\"angle_max_deg\":"<<mx<<"}\n";
 }
}
static int blockStart(int x,int phase){int a=x-phase;int q=a/4;if(a<0&&a%4)--q;return phase+4*q;}
int main(int argc,char**){
 try{
  require(argc==1,"synthetic-only executable accepts no inputs");std::cout<<std::setprecision(12);
  ideal();const Eigen::Vector3d truth(.4,.3,1);
  for(double intercept:{.3,1.,2.,3.}){
  auto f=raster(64,64);
  for(int y=0;y<f.height;++y)for(int x=0;x<f.width;++x)f.depthMm[at(f,x,y)]=uint16_t(std::lround(1000*planeZ(x,y,f,intercept)));
  compare("tilted_mm_z"+std::to_string(intercept),f,&truth);
  for(int phase:{0,1,3}){auto repeat=f;
   // Blocks begin at phase mod4. Analytic samples outside raster define edge
   // blocks: no clamp/shift/fitting; this is not an exporter reconstruction.
   for(int y=0;y<f.height;++y)for(int x=0;x<f.width;++x)repeat.depthMm[at(f,x,y)]=uint16_t(std::lround(1000*planeZ(blockStart(x,phase),blockStart(y,phase),f,intercept)));
   std::cout<<"{\"block_start_phase\":"<<phase<<",\"unequal_transition_start_phase\":"<<(phase+3)%4<<",\"intercept_m\":"<<intercept<<"}\n";
   compare("tilted_repeat4_start"+std::to_string(phase)+"_transition"+std::to_string((phase+3)%4)+"_z"+std::to_string(intercept),repeat,&truth);
  }
  }
  for(auto dims: {std::pair<int,int>{1,12},{2,12},{3,12},{4,12},{12,1},{12,2},{12,3},{12,4},{4,4},{5,5},{32,24}})compare("border_"+std::to_string(dims.first)+"x"+std::to_string(dims.second),raster(dims.first,dims.second));
  // Axial synthetic depth steps named for offset size, not gravity-aligned
  // toy/head geometry. They test support retention only, not hazard recall.
  for(int cm:{2,4,12}){auto g=raster();for(int y=8;y<12;++y)for(int x=8;x<12;++x)g.depthMm[at(g,x,y)]=uint16_t(2000-10*cm);
   // Center (7,8) sees the patch at +1..+4: 2/4cm at 2m pass
   // the unchanged gate and bridge this real depth step. No fake rejection.
   auto b=n3::compute(g);
   require(reasonAt(b,at(g,7,8))==(cm==12?R::Discontinuity:R::Valid),"low-step gate behavior");
   compare("low_axial_"+std::to_string(cm)+"cm",g);
  }
  for(const std::string name:{"head_patch","overhang_gap","drop_step","hole"}){
   auto g=raster();for(int y=8;y<16;++y)for(int x=8;x<24;++x)g.depthMm[at(g,x,y)]=name=="hole"?0:name=="drop_step"?2300:1500;
   if(name=="overhang_gap")for(int y=10;y<12;++y)for(int x=8;x<24;++x)g.depthMm[at(g,x,y)]=0;
   compare(name,g);
  }
  {auto g=raster(12,12);g.depthMm[at(g,4,4)]=0;
   require(reasonAt(n3::compute(g),at(g,2,2))==R::Valid,"axial-only support disclosure");
   compare("diagonal_interior_hole_not_checked_by_axial_stencil",g);
  }
  // Every intervening axis sample, not just endpoint, must be admitted and
  // within strict 5% center depth. Isolated disruptions leave other axis flat.
  for(int axis=0;axis<2;++axis)for(int off=1;off<=4;++off)for(int depth:{0,4000,1899,1900,2100,2101}){
   auto g=raster(12,12);g.depthMm[at(g,2+(axis==0?off:0),2+(axis==1?off:0))]=uint16_t(depth);
   auto b=n3::compute(g);R expected=(depth==0||depth==4000)?R::MissingNeighbor:(depth==1899||depth==2101)?R::Discontinuity:R::Valid;
   require(reasonAt(b,at(g,2,2))==expected,"intermediate support or strict 5% gate");
   compare("axis"+std::to_string(axis)+"_offset"+std::to_string(off)+"_depth"+std::to_string(depth),g);
  }
  {auto g=raster(12,12);g.depthMm[at(g,3,2)]=2101;g.depthMm[at(g,2,4)]=0;
   require(reasonAt(n3::compute(g),at(g,2,2))==R::MissingNeighbor,"missing support precedence");
   compare("missing_over_discontinuous_precedence",g);
  }
  std::cout<<"{\"status\":\"pass\",\"synthetic_only\":true,\"accuracy_gain_required\":false,\"navigation_safety_evaluated\":false}\n";
  return 0;
 }catch(const std::exception& e){std::cerr<<"fixture failure: "<<e.what()<<"\n";return 1;}
}
