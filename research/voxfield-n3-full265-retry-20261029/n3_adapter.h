#pragma once
/*
N3 experimental native-spacing candidate, not released Voxfield code.
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

N2 baseline unchanged. All geometry/point order remains N2 unprojection.
Only normal support changes to +4 export pixels, with every intervening axial
sample required admitted and within the same frozen 5% center-depth gate.
No normal interpolation, confidence invention, axial missing-support crossing, decimation,
new poses/calibration or point removal. Four-pixel spacing is specific to the
observed Koivu export pattern, not a universal iPhone resolution assumption.
Only two axial support segments are checked, NOT the full footprint/triangle;
interior or diagonal holes/discontinuities may escape these support checks.
*/
#include "n2_adapter.h"
namespace n3 {
using Raster=n2::Raster;
using Result=n2::Result;
using Reason=n2::Reason;
using Vec=n2::Vec;
constexpr int kSpacing=4;
inline Result compute(const Raster& f){
 if(f.width<=0||f.height<=0||size_t(f.width)>std::numeric_limits<size_t>::max()/size_t(f.height))throw std::invalid_argument("invalid raster dimensions");
 if(f.depthMm.size()!=size_t(f.width)*size_t(f.height))throw std::invalid_argument("depth size mismatch");
 if(!std::isfinite(f.fx)||!std::isfinite(f.fy)||!std::isfinite(f.cx)||!std::isfinite(f.cy)||f.fx<=0||f.fy<=0)throw std::invalid_argument("invalid intrinsics");
 Result out;
 for(int v=0;v<f.height;++v)for(int u=0;u<f.width;++u){
  const size_t i=size_t(v)*size_t(f.width)+size_t(u);const uint16_t d=f.depthMm[i];
  if(d==0){++out.zero;continue;}if(d>=4000){++out.far;continue;}
  const Vec p=n2::unproject(u,v,d,f);if(!p.allFinite())throw std::invalid_argument("nonfinite unprojected point");
  Vec normal=Vec::Zero();Reason reason=Reason::Boundary;
  if(f.width-u>kSpacing&&f.height-v>kSpacing){
   bool missing=false,edge=false;
   for(int delta=1;delta<=kSpacing;++delta){
    const uint16_t right=f.depthMm[i+size_t(delta)],down=f.depthMm[i+size_t(delta)*size_t(f.width)];
    missing=missing||!n2::admitted(right)||!n2::admitted(down);
    edge=edge||n2::discontinuous(d,right)||n2::discontinuous(d,down);
   }
   if(missing)reason=Reason::MissingNeighbor;
   else if(edge)reason=Reason::Discontinuity;
   else reason=n2::tripletNormal(p,n2::unproject(u+kSpacing,v,f.depthMm[i+kSpacing],f),n2::unproject(u,v+kSpacing,f.depthMm[i+size_t(kSpacing)*size_t(f.width)],f),&normal);
  }
  out.points.push_back(p);out.normals.push_back(normal);out.pixelIndices.push_back(i);out.reasons.push_back(reason);++out.counts[static_cast<unsigned>(reason)];
 }
 return out;
}
} // namespace n3
