#pragma once
/*
N1 organized-perspective adapter derived from computeNormalImage in Voxfield
voxblox_ros/src/np_tsdf_server.cc, revision
78ee6403720e0aed87f4720c04c813bb38a3b260.
Copyright (c) 2022, ETHZ ASL, V4RL. All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:
* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.
* Neither the name of voxblox nor the names of its contributors may be used to
  endorse or promote products derived from this software without specific prior
  written permission.
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

DISCLOSED ADAPTATION, not verbatim released wrapper:
- Direct original organized raster, no buggy bool-depth reprojection, no resize.
- Integer pixel coordinates and axial uint16 millimetres; admitted 0<mm<4000.
- Perspective +u/+v only; no wrap or out-of-bounds accesses.
- Discontinuity is strict >0.05 of center axial depth; integer diff*20>center
  makes exactly-5-percent behavior explicit without floating-roundoff ties.
- Finite, nonzero cross-product gate (upstream coordinate epsilon 1e-6).
  Cross-product norm has units m^2, not m: reusing this numeric coordinate
  epsilon as an area threshold is disclosed and NOT sensor-calibrated. For a
  frontoparallel plane area=z^2/(fx*fy); clean close/high-focal-length samples
  may therefore have unavailable (Degenerate) normals. Points remain retained.
- Sign fixed dx.cross(dy); frontoparallel optical plane gives +z. No viewpoint
  flip, GT normal, smoothing, fill, reordering, floor classifier or point loss.
- Unavailable normals are zero plus reason. Every admitted point is retained.
*/
#include <Eigen/Core>
#include <Eigen/Geometry>
#include <array>
#include <cmath>
#include <cstdint>
#include <limits>
#include <stdexcept>
#include <vector>

namespace n1 {
constexpr float kEpsilon = 1e-6f;
constexpr double kSmoothRatio = 0.05;
enum class Reason : unsigned { Valid=0, Boundary=1, MissingNeighbor=2,
  Discontinuity=3, Nonfinite=4, Degenerate=5, Count=6 };
inline const char* reasonName(Reason r) {
  static const char* names[]={"valid","boundary","missing_neighbor",
    "discontinuity","nonfinite","degenerate"};
  return names[static_cast<unsigned>(r)];
}
struct Raster {
  int width=0,height=0;
  double fx=0,fy=0,cx=0,cy=0;
  std::vector<uint16_t> depthMm;
};
using Vec = Eigen::Vector3f;
using Vecs = std::vector<Vec,Eigen::aligned_allocator<Vec>>;
struct Result {
  Vecs points,normals;
  std::vector<size_t> pixelIndices;
  std::vector<Reason> reasons;
  std::array<size_t,static_cast<unsigned>(Reason::Count)> counts{};
  size_t zero=0,far=0;
};
inline bool admitted(uint16_t d){return d>0 && d<4000;}
inline bool discontinuous(uint16_t center,uint16_t neighbor){
  const unsigned delta=center>neighbor?center-neighbor:neighbor-center;
  return delta*20u>static_cast<unsigned>(center);
}
inline Vec unproject(int u,int v,uint16_t mm,const Raster& f){
  const double z=double(mm)*0.001;
  return Vec(float((double(u)-f.cx)*z/f.fx),
             float((double(v)-f.cy)*z/f.fy),float(z));
}
inline Reason tripletNormal(const Vec& center,const Vec& right,
                            const Vec& down,Vec* normal){
  if(!normal)throw std::invalid_argument("null normal output");
  normal->setZero();
  if(!center.allFinite()||!right.allFinite()||!down.allFinite())
    return Reason::Nonfinite;
  const Vec cross=(right-center).cross(down-center);
  const float norm=cross.norm();
  if(!cross.allFinite()||!std::isfinite(norm))return Reason::Nonfinite;
  if(!(norm>kEpsilon))return Reason::Degenerate;
  *normal=cross/norm;
  if(!normal->allFinite()){normal->setZero();return Reason::Nonfinite;}
  return Reason::Valid;
}
inline Result compute(const Raster& f){
  if(f.width<=0||f.height<=0 ||
     size_t(f.width)>std::numeric_limits<size_t>::max()/size_t(f.height))
    throw std::invalid_argument("invalid raster dimensions");
  const size_t n=size_t(f.width)*size_t(f.height);
  if(f.depthMm.size()!=n)throw std::invalid_argument("depth size mismatch");
  if(!std::isfinite(f.fx)||!std::isfinite(f.fy)||!std::isfinite(f.cx)||
     !std::isfinite(f.cy)||f.fx<=0||f.fy<=0)
    throw std::invalid_argument("invalid intrinsics");
  Result out;
  for(int v=0;v<f.height;++v)for(int u=0;u<f.width;++u){
    const size_t i=size_t(v)*size_t(f.width)+size_t(u);
    const uint16_t d=f.depthMm[i];
    if(d==0){++out.zero;continue;}
    if(d>=4000){++out.far;continue;}
    const Vec p=unproject(u,v,d,f);
    // A nonfinite point itself is invalid input, not a point silently removed.
    if(!p.allFinite())throw std::invalid_argument("nonfinite unprojected point");
    Vec normal=Vec::Zero(); Reason reason=Reason::Boundary;
    if(u+1<f.width && v+1<f.height){
      const uint16_t dx=f.depthMm[i+1],dy=f.depthMm[i+size_t(f.width)];
      if(!admitted(dx)||!admitted(dy))reason=Reason::MissingNeighbor;
      else if(discontinuous(d,dx)||discontinuous(d,dy))reason=Reason::Discontinuity;
      else reason=tripletNormal(p,unproject(u+1,v,dx,f),
                               unproject(u,v+1,dy,f),&normal);
    }
    out.points.push_back(p);out.normals.push_back(normal);
    out.pixelIndices.push_back(i);out.reasons.push_back(reason);
    ++out.counts[static_cast<unsigned>(reason)];
  }
  return out;
}
} // namespace n1
