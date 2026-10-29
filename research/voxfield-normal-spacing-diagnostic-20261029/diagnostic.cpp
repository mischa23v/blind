#include "n2_adapter.h"
#include <fstream>
#include <iostream>
#include <sstream>
#include <iomanip>
#include <array>
void measure(const n2::Raster& f,const std::string& label,bool synthetic){
 auto r=n2::compute(f);size_t axis=0,equalTriplet=0;double error=0;size_t valid=0;
 Eigen::Vector3d truth(.4,.3,1);truth.normalize();
 for(size_t j=0;j<r.points.size();++j){if(r.reasons[j]!=n2::Reason::Valid)continue;++valid;
 const auto& n=r.normals[j];if(n.x()==0&&n.y()==0&&n.z()==1)++axis;
 size_t i=r.pixelIndices[j];if(f.depthMm[i]==f.depthMm[i+1]&&f.depthMm[i]==f.depthMm[i+f.width])++equalTriplet;
 if(synthetic)error+=std::acos(std::max(-1.,std::min(1.,n.cast<double>().dot(truth))))*180/std::acos(-1.);
 }
 if(valid==0)throw std::runtime_error("no valid normals");
 std::cout<<"NORMAL "<<label<<" interior_positions "<<size_t(f.width-1)*size_t(f.height-1)<<" unavailable "<<(r.points.size()-valid)<<" admitted "<<r.points.size()<<" valid "<<valid<<" exact_plus_z "<<axis<<" equal_depth_triplets "<<equalTriplet<<" reasons";for(auto c:r.counts)std::cout<<" "<<c;std::cout<<" mean_angle_deg "<<(synthetic?error/valid:-1)<<"\n";
 for(int a=0;a<2;++a){std::array<size_t,4> count{},equal{},change{};for(int v=0;v<f.height-(a==1);++v)for(int u=0;u<f.width-(a==0);++u){size_t i=size_t(v)*f.width+u,k=i+(a?f.width:1);if(!n2::admitted(f.depthMm[i])||!n2::admitted(f.depthMm[k]))continue;int phase=(a?v:u)%4;++count[phase];if(f.depthMm[i]==f.depthMm[k])++equal[phase];else ++change[phase];}for(int p=0;p<4;++p)std::cout<<"PHASE "<<label<<" axis "<<a<<" phase "<<p<<" admitted_pairs "<<count[p]<<" equal "<<equal[p]<<" unequal "<<change[p]<<"\n";}
}
int main(int argc,char**argv){if(argc!=2)return 2;std::ifstream in(argv[1]);std::string line;int count=0;n2::Raster first;while(std::getline(in,line)){std::istringstream s(line);std::string id,raw,rgb;n2::Raster f;s>>id>>raw>>rgb>>f.width>>f.height>>f.fx>>f.fy>>f.cx>>f.cy;if(!s||f.width!=738||f.height!=994)return 3;f.depthMm.resize(size_t(f.width)*f.height);std::ifstream data(raw,std::ios::binary);data.read(reinterpret_cast<char*>(f.depthMm.data()),f.depthMm.size()*2);if(!data||data.peek()!=EOF)return 4;measure(f,id,false);if(count++==0)first=f;}if(count!=3)return 5;
 // Synthetic optical plane .4X+.3Y+Z=2, actual first-frame focal length.
 n2::Raster f;f.width=64;f.height=64;f.fx=first.fx;f.fy=first.fy;f.cx=31.5;f.cy=31.5;f.depthMm.resize(4096);
 for(int v=0;v<64;++v)for(int u=0;u<64;++u)f.depthMm[v*64+u]=uint16_t(std::lround(2000/(1+.4*(u-f.cx)/f.fx+.3*(v-f.cy)/f.fy)));
 measure(f,"analytic_plane_mm_quantized",true);auto coarse=f;for(int v=0;v<64;++v)for(int u=0;u<64;++u)coarse.depthMm[v*64+u]=f.depthMm[(v/4*4)*64+u/4*4];measure(coarse,"same_plane_nearest_repeat4",true);
 // Unquantized ideal uses exact same N2 triplet implementation, unchanged float point conversion.
 double err=0;size_t valid=0;Eigen::Vector3d truth(.4,.3,1);truth.normalize();auto p=[&](int u,int v)->n2::Vec{double z=2/(1+.4*(u-f.cx)/f.fx+.3*(v-f.cy)/f.fy);return n2::Vec(float((u-f.cx)*z/f.fx),float((v-f.cy)*z/f.fy),float(z));};for(int v=0;v<63;++v)for(int u=0;u<63;++u){n2::Vec n;if(n2::tripletNormal(p(u,v),p(u+1,v),p(u,v+1),&n)!=n2::Reason::Valid)return 6;err+=std::acos(std::max(-1.,std::min(1.,n.cast<double>().dot(truth))))*180/std::acos(-1.);++valid;}std::cout<<"IDEAL unquantized valid "<<valid<<" mean_angle_deg "<<err/valid<<"\n";
}
