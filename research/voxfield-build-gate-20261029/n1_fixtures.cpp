#include "n1_adapter.h"
#include <iostream>
#include <string>
#include <functional>
#include <utility>

namespace {
size_t checks=0;
void require(bool b,const char* s){++checks;if(!b)throw std::runtime_error(s);}
void rejects(const std::function<void()>& f,const char* s){bool caught=false;
  try{f();}catch(const std::invalid_argument&){caught=true;}require(caught,s);}
n1::Raster raster(int w,int h,uint16_t d=1000){n1::Raster r;
  r.width=w;r.height=h;r.fx=100;r.fy=100;r.cx=0;r.cy=0;
  r.depthMm.assign(size_t(w)*size_t(h),d);return r;}
void preservation(const n1::Raster& f,const n1::Result& r){size_t j=0,z=0,far=0;
  for(size_t i=0;i<f.depthMm.size();++i){const auto d=f.depthMm[i];
    if(!d){++z;continue;}if(d>=4000){++far;continue;}
    require(j<r.points.size(),"lost admitted point");
    require(r.pixelIndices[j]==i,"changed raster order");
    require((r.points[j]-n1::unproject(int(i%f.width),int(i/f.width),d,f)).norm()==0,
            "changed admitted point");
    require(r.normals[j].allFinite(),"nonfinite output normal");
    require(r.reasons[j]==n1::Reason::Valid || r.normals[j].isZero(0),
            "unavailable normal not zero");++j;}
  require(j==r.points.size()&&j==r.normals.size()&&j==r.reasons.size()&&
          j==r.pixelIndices.size(),"arrays differ");
  require(z==r.zero&&far==r.far,"depth domain accounting");
  size_t total=0;for(auto n:r.counts)total+=n;
  require(total==j,"reason counts mismatch");}
}
int main(){try{
  // Frontoparallel, fixed dx cross dy sign; no viewpoint flip.
  auto f=raster(4,3);auto r=n1::compute(f);preservation(f,r);
  require(r.counts[0]==6&&r.counts[1]==6,"perspective border counts");
  require((r.normals[0]-n1::Vec(0,0,1)).norm()<1e-6,"fixed optical sign");
  require(r.reasons[3]==n1::Reason::Boundary&&r.reasons[8]==n1::Reason::Boundary,
          "right/bottom not unavailable");
  // Narrow raster bounds never access an unavailable neighbor.
  for(auto wh:{std::pair<int,int>{1,7},{7,1},{1,1}}){auto a=raster(wh.first,wh.second);
    auto b=n1::compute(a);preservation(a,b);
    require(b.counts[1]==a.depthMm.size(),"narrow raster boundary");}
  // Exact asymmetrical K, integer pixels, axial mm, preserved masks.
  f=raster(3,2);f.fx=2;f.fy=4;f.cx=.25;f.cy=.75;
  f.depthMm={1000,0,4000,3999,1000,1000};r=n1::compute(f);preservation(f,r);
  require((r.points[0]-n1::Vec(-.125f,-.1875f,1)).norm()<1e-7,"K/mm convention");
  require(r.zero==1&&r.far==1&&r.points.size()==4,"mask contract");
  require(r.reasons[0]==n1::Reason::MissingNeighbor,"missing-depth reason");
  auto changed=f;changed.fx=4;auto changedR=n1::compute(changed);
  require(std::abs(changedR.points[0].x()+.0625f)<1e-7,"per-frame K");
  // +/-5% exactly admitted; greater changes rejected in either direction.
  for(uint16_t d:{uint16_t(949),uint16_t(950),uint16_t(951),uint16_t(1049),
                   uint16_t(1050),uint16_t(1051)}){
    auto a=raster(2,2);a.depthMm[1]=d;auto b=n1::compute(a);preservation(a,b);
    const bool bad=d==949||d==1051;
    require(b.reasons[0]==(bad?n1::Reason::Discontinuity:n1::Reason::Valid),
            "strict rational five-percent gate");}
  {auto a=raster(2,2);a.depthMm[2]=1051;auto b=n1::compute(a);
    require(b.reasons[0]==n1::Reason::Discontinuity,"vertical gate");}
  // Analytic plane 0.2*x -0.1*y + z=1; quantized mm input only, no GT normals input.
  f=raster(11,11);f.cx=5;f.cy=5;
  for(int v=0;v<f.height;++v)for(int u=0;u<f.width;++u){
    double z=1.0/(1.0+.2*(u-f.cx)/f.fx-.1*(v-f.cy)/f.fy);
    f.depthMm[size_t(v)*f.width+u]=uint16_t(std::lround(z*1000));}
  r=n1::compute(f);preservation(f,r);
  const n1::Vec expected=n1::Vec(.2f,-.1f,1).normalized();
  require(r.counts[0]==100,"sloped valid count");
  require(r.normals[5*11+5].dot(expected)>.999,"analytic sloped sign/direction");
  // Area-unit control: only frame_00001 manifest intrinsics were inspected, no
  // recorded depth loaded. Cross-product magnitude is z^2/(fx*fy) in m^2.
  // Keep the frozen numeric1e-6 threshold even when it rejects a clean plane.
  constexpr double originalFx=810.82548516100394;
  for(uint16_t mm:{uint16_t(300),uint16_t(1000),uint16_t(3000)}){
    auto a=raster(4,3,mm);a.fx=originalFx;a.fy=originalFx;a.cx=1.5;a.cy=1;
    auto b=n1::compute(a);preservation(a,b);
    const double z=double(mm)*.001,area=z*z/(a.fx*a.fy);
    const bool unavailable=mm==300;
    require((area<=n1::kEpsilon)==unavailable,"analytic area threshold control");
    require(b.points.size()==12&&b.counts[1]==6,"area control preservation/border");
    require(b.counts[0]==(unavailable?0u:6u)&&b.counts[5]==(unavailable?6u:0u),
            "fixed epsilon clean-plane reason counts");
    for(size_t i=0;i<b.points.size();++i)if(b.reasons[i]==n1::Reason::Valid)
      require((b.normals[i]-n1::Vec(0,0,1)).norm()<1e-6,"area control plane normal");
    std::cout<<"{\"fixture\":\"normal_area_units\",\"depth_m\":"<<z
      <<",\"fx_px\":"<<originalFx<<",\"expected_cross_area_m2\":"<<area
      <<",\"threshold_m2\":0.000001,\"admitted\":"<<b.points.size()
      <<",\"valid\":"<<b.counts[0]<<",\"degenerate\":"<<b.counts[5]
      <<",\"boundary\":"<<b.counts[1]<<"}\n";
  }
  // Degenerate and nonfinite triplets explicitly unavailable; reversing order flips sign.
  n1::Vec n;auto p=n1::Vec::Zero();
  require(n1::tripletNormal(p,p,p,&n)==n1::Reason::Degenerate&&n.isZero(0),"degenerate");
  require(n1::tripletNormal(p,n1::Vec(1e-4f,0,0),n1::Vec(0,1e-4f,0),&n)==
          n1::Reason::Degenerate,"epsilon gate");
  auto bad=n1::Vec(0,0,std::numeric_limits<float>::infinity());
  require(n1::tripletNormal(p,bad,n1::Vec(0,1,0),&n)==n1::Reason::Nonfinite&&
          n.isZero(0),"nonfinite");
  bad.z()=std::numeric_limits<float>::quiet_NaN();
  require(n1::tripletNormal(p,n1::Vec(1,0,0),bad,&n)==n1::Reason::Nonfinite,"NaN");
  require(n1::tripletNormal(p,n1::Vec(0,1,0),n1::Vec(1,0,0),&n)==n1::Reason::Valid&&
          (n-n1::Vec(0,0,-1)).norm()<1e-6,"opposite order sign control");
  // A point-sparse silhouette/hole retains all depth observations; no normal filling.
  f=raster(5,5);f.depthMm[12]=0;f.depthMm[6]=500;r=n1::compute(f);preservation(f,r);
  require(r.points.size()==24&&r.counts[2]>0&&r.counts[3]>0,"hole/silhouette accounting");
  f=raster(2,2);f.fx=1e12;f.fy=1e12;r=n1::compute(f);preservation(f,r);
  require(r.reasons[0]==n1::Reason::Degenerate,"organized degeneracy");
  // Invalid input fails rather than silently deleting any admitted point.
  rejects([]{auto a=raster(2,2);a.depthMm.pop_back();n1::compute(a);},"size mismatch");
  rejects([]{auto a=raster(2,2);a.fx=0;n1::compute(a);},"zero K");
  rejects([]{auto a=raster(2,2);a.cy=std::numeric_limits<double>::quiet_NaN();
    n1::compute(a);},"nonfinite K");
  rejects([]{auto a=raster(2,2);a.fx=1e-300;n1::compute(a);},"nonfinite point");
  rejects([]{n1::Raster a;n1::compute(a);},"invalid dimensions");
  std::cout<<"{\"suite\":\"N1_provider_only\",\"status\":\"PASS\",\"assertions\":"
           <<checks<<",\"scope\":\"synthetic organized rasters; no mapper or real scene\","
           <<"\"normalSign\":\"dx_cross_dy\",\"ratio\":0.05,\"epsilon\":0.000001}\n";
  return 0;
}catch(const std::exception& e){std::cerr<<"N1_FAIL: "<<e.what()<<"\n";return 2;}}
