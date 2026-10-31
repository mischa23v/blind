#include "n2_adapter.h"
#include "../build-gate/n1_adapter.h"
#include <iostream>
#include <string>
#include <functional>
#include <utility>

namespace {
size_t checks=0;
void require(bool b,const char* s){++checks;if(!b)throw std::runtime_error(s);}
void rejects(const std::function<void()>& f,const char* s){bool caught=false;
  try{f();}catch(const std::invalid_argument&){caught=true;}require(caught,s);}
n2::Raster raster(int w,int h,uint16_t d=1000){n2::Raster r;
  r.width=w;r.height=h;r.fx=100;r.fy=100;r.cx=0;r.cy=0;
  r.depthMm.assign(size_t(w)*size_t(h),d);return r;}
void preservation(const n2::Raster& f,const n2::Result& r){size_t j=0,z=0,far=0;
  for(size_t i=0;i<f.depthMm.size();++i){const auto d=f.depthMm[i];
    if(!d){++z;continue;}if(d>=4000){++far;continue;}
    require(j<r.points.size(),"lost admitted point");
    require(r.pixelIndices[j]==i,"changed raster order");
    require((r.points[j]-n2::unproject(int(i%f.width),int(i/f.width),d,f)).norm()==0,
            "changed admitted point");
    require(r.normals[j].allFinite(),"nonfinite output normal");
    require(r.reasons[j]==n2::Reason::Valid || r.normals[j].isZero(0),
            "unavailable normal not zero");++j;}
  require(j==r.points.size()&&j==r.normals.size()&&j==r.reasons.size()&&
          j==r.pixelIndices.size(),"arrays differ");
  require(z==r.zero&&far==r.far,"depth domain accounting");
  size_t total=0;for(auto n:r.counts)total+=n;
  require(total==j,"reason counts mismatch");}
}
int main(){try{
  // Frontoparallel, fixed dx cross dy sign; no viewpoint flip.
  auto f=raster(4,3);auto r=n2::compute(f);preservation(f,r);
  require(r.counts[0]==6&&r.counts[1]==6,"perspective border counts");
  require((r.normals[0]-n2::Vec(0,0,1)).norm()<1e-6,"fixed optical sign");
  require(r.reasons[3]==n2::Reason::Boundary&&r.reasons[8]==n2::Reason::Boundary,
          "right/bottom not unavailable");
  // Narrow raster bounds never access an unavailable neighbor.
  for(auto wh:{std::pair<int,int>{1,7},{7,1},{1,1}}){auto a=raster(wh.first,wh.second);
    auto b=n2::compute(a);preservation(a,b);
    require(b.counts[1]==a.depthMm.size(),"narrow raster boundary");}
  // Exact asymmetrical K, integer pixels, axial mm, preserved masks.
  f=raster(3,2);f.fx=2;f.fy=4;f.cx=.25;f.cy=.75;
  f.depthMm={1000,0,4000,3999,1000,1000};r=n2::compute(f);preservation(f,r);
  require((r.points[0]-n2::Vec(-.125f,-.1875f,1)).norm()<1e-7,"K/mm convention");
  require(r.zero==1&&r.far==1&&r.points.size()==4,"mask contract");
  require(r.reasons[0]==n2::Reason::MissingNeighbor,"missing-depth reason");
  auto changed=f;changed.fx=4;auto changedR=n2::compute(changed);
  require(std::abs(changedR.points[0].x()+.0625f)<1e-7,"per-frame K");
  // +/-5% exactly admitted; greater changes rejected in either direction.
  for(uint16_t d:{uint16_t(949),uint16_t(950),uint16_t(951),uint16_t(1049),
                   uint16_t(1050),uint16_t(1051)}){
    auto a=raster(2,2);a.depthMm[1]=d;auto b=n2::compute(a);preservation(a,b);
    const bool bad=d==949||d==1051;
    require(b.reasons[0]==(bad?n2::Reason::Discontinuity:n2::Reason::Valid),
            "strict rational five-percent gate");}
  {auto a=raster(2,2);a.depthMm[2]=1051;auto b=n2::compute(a);
    require(b.reasons[0]==n2::Reason::Discontinuity,"vertical gate");}
  // Analytic plane 0.2*x -0.1*y + z=1; quantized mm input only, no GT normals input.
  f=raster(11,11);f.cx=5;f.cy=5;
  for(int v=0;v<f.height;++v)for(int u=0;u<f.width;++u){
    double z=1.0/(1.0+.2*(u-f.cx)/f.fx-.1*(v-f.cy)/f.fy);
    f.depthMm[size_t(v)*f.width+u]=uint16_t(std::lround(z*1000));}
  r=n2::compute(f);preservation(f,r);
  const n2::Vec expected=n2::Vec(.2f,-.1f,1).normalized();
  require(r.counts[0]==100,"sloped valid count");
  require(r.normals[5*11+5].dot(expected)>.999,"analytic sloped sign/direction");
  // Area-unit control: only frame_00001 manifest intrinsics were inspected, no
  // recorded depth loaded. Cross-product magnitude is z^2/(fx*fy) in m^2.
  // N1 baseline remains unchanged. N2 removes the numerical area cutoff only.
  constexpr double originalFx=810.82548516100394;
  for(uint16_t mm:{uint16_t(300),uint16_t(1000),uint16_t(3000)}){
    auto a=raster(4,3,mm);a.fx=originalFx;a.fy=originalFx;a.cx=1.5;a.cy=1;
    auto b=n2::compute(a);preservation(a,b);
    const double z=double(mm)*.001,area=z*z/(a.fx*a.fy);
    n1::Raster old;old.width=a.width;old.height=a.height;old.fx=a.fx;old.fy=a.fy;
    old.cx=a.cx;old.cy=a.cy;old.depthMm=a.depthMm;const auto baseline=n1::compute(old);
    require(baseline.points.size()==b.points.size(),"N1 N2 admitted count drift");
    require(baseline.pixelIndices==b.pixelIndices,"N1 N2 pixel order drift");
    for(size_t i=0;i<b.points.size();++i)
      require((baseline.points[i]-b.points[i]).norm()==0,"N1 N2 point mutation");
    require(baseline.counts[0]==(mm==300?0u:6u),"frozen N1 baseline normal count");

    const bool unavailable=false;
    require(area>0,"positive analytic area");
    require(b.points.size()==12&&b.counts[1]==6,"area control preservation/border");
    require(b.counts[0]==(unavailable?0u:6u)&&b.counts[5]==(unavailable?6u:0u),
            "numerical-only clean-plane reason counts");
    for(size_t i=0;i<b.points.size();++i)if(b.reasons[i]==n2::Reason::Valid)
      require((b.normals[i]-n2::Vec(0,0,1)).norm()<1e-6,"area control plane normal");
    std::cout<<"{\"fixture\":\"normal_area_units\",\"depth_m\":"<<z
      <<",\"fx_px\":"<<originalFx<<",\"expected_cross_area_m2\":"<<area
      <<",\"areaCutoff\":false,\"admitted\":"<<b.points.size()
      <<",\"valid\":"<<b.counts[0]<<",\"degenerate\":"<<b.counts[5]
      <<",\"boundary\":"<<b.counts[1]<<"}\n";
  }
  // Degenerate and nonfinite triplets explicitly unavailable; reversing order flips sign.
  n2::Vec n;auto p=n2::Vec::Zero();
  require(n2::tripletNormal(p,p,p,&n)==n2::Reason::Degenerate&&n.isZero(0),"degenerate");
  require(n2::tripletNormal(p,n2::Vec(1e-4f,0,0),n2::Vec(0,1e-4f,0),&n)==
          n2::Reason::Valid,"small positive area remains valid");
  auto bad=n2::Vec(0,0,std::numeric_limits<float>::infinity());
  require(n2::tripletNormal(p,bad,n2::Vec(0,1,0),&n)==n2::Reason::Nonfinite&&
          n.isZero(0),"nonfinite");
  bad.z()=std::numeric_limits<float>::quiet_NaN();
  require(n2::tripletNormal(p,n2::Vec(1,0,0),bad,&n)==n2::Reason::Nonfinite,"NaN");
  require(n2::tripletNormal(p,n2::Vec(0,1,0),n2::Vec(1,0,0),&n)==n2::Reason::Valid&&
          (n-n2::Vec(0,0,-1)).norm()<1e-6,"opposite order sign control");
  // Extremely small positive area/near-collinearity are numerical validity only.
  n2::TripletDiagnostics diag;
  require(n2::tripletNormal(p,n2::Vec(1e-30f,0,0),n2::Vec(0,1e-30f,0),&n,&diag)==
          n2::Reason::Valid&&diag.crossAreaM2>0&&n.allFinite(),"tiny positive area");
  require(n2::tripletNormal(p,n2::Vec(1,0,0),n2::Vec(1,1e-20f,0),&n,&diag)==
          n2::Reason::Valid&&diag.sinAngle>0&&diag.sinAngle<1e-15,
          "near-collinear numerical-validity not confidence");
  require((n-n2::Vec(0,0,1)).norm()<1e-6,"near-collinear direction");
  require(n2::tripletNormal(p,n2::Vec(1,0,0),n2::Vec(2,0,0),&n,&diag)==
          n2::Reason::Degenerate&&diag.crossAreaM2==0&&n.isZero(0),"exact collinear");
  std::cout<<"{\"fixture\":\"near_collinear_policy\",\"numericalValidNotConfidence\":true,"
           <<"\"areaCutoff\":false}\n";
  // A point-sparse silhouette/hole retains all depth observations; no normal filling.
  f=raster(5,5);f.depthMm[12]=0;f.depthMm[6]=500;r=n2::compute(f);preservation(f,r);
  require(r.points.size()==24&&r.counts[2]>0&&r.counts[3]>0,"hole/silhouette accounting");
  f=raster(2,2);f.fx=1e12;f.fy=1e12;r=n2::compute(f);preservation(f,r);
  require(r.reasons[0]==n2::Reason::Valid,"organized tiny-positive-area retained");
  f.fx=1e300;f.fy=1e300;r=n2::compute(f);preservation(f,r);
  require(r.reasons[0]==n2::Reason::Degenerate,"float-input coincident points remain degenerate");
  // Invalid input fails rather than silently deleting any admitted point.
  rejects([]{auto a=raster(2,2);a.depthMm.pop_back();n2::compute(a);},"size mismatch");
  rejects([]{auto a=raster(2,2);a.fx=0;n2::compute(a);},"zero K");
  rejects([]{auto a=raster(2,2);a.cy=std::numeric_limits<double>::quiet_NaN();
    n2::compute(a);},"nonfinite K");
  rejects([]{auto a=raster(2,2);a.fx=1e-300;n2::compute(a);},"nonfinite point");
  rejects([]{n2::Raster a;n2::compute(a);},"invalid dimensions");
  std::cout<<"{\"suite\":\"N2_provider_only\",\"status\":\"PASS\",\"assertions\":"
           <<checks<<",\"scope\":\"synthetic organized rasters; no mapper or real scene\","
           <<"\"normalSign\":\"dx_cross_dy\",\"ratio\":0.05,\"areaCutoff\":false}\n";
  return 0;
}catch(const std::exception& e){std::cerr<<"N2_FAIL: "<<e.what()<<"\n";return 2;}}
