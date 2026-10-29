#include "n3_adapter.h"
#include <fstream>
#include <iostream>
#include <sstream>
#include <iomanip>
#include <array>
void measure(const n2::Raster& f,const std::string& label,bool synthetic,bool n3arm){
 auto r=n3arm?n3::compute(f):n2::compute(f);size_t axis=0,equalTriplet=0;double error=0;size_t valid=0;
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
int main(int argc,char**argv){if(argc!=2)return 2;std::ifstream in(argv[1]);std::string line;int count=0;while(std::getline(in,line)){std::istringstream s(line);std::string id,raw,rgb;n2::Raster f;s>>id>>raw>>rgb>>f.width>>f.height>>f.fx>>f.fy>>f.cx>>f.cy;if(!s||f.width!=738||f.height!=994)return 3;f.depthMm.resize(size_t(f.width)*f.height);std::ifstream data(raw,std::ios::binary);data.read(reinterpret_cast<char*>(f.depthMm.data()),f.depthMm.size()*2);if(!data||data.peek()!=EOF)return 4;
 {auto a=n2::compute(f),b=n3::compute(f);if(a.pixelIndices!=b.pixelIndices||a.points.size()!=b.points.size()||a.zero!=b.zero||a.far!=b.far)return 7;for(size_t j=0;j<a.points.size();++j)if(!(a.points[j].array()==b.points[j].array()).all())return 8;std::cout<<"RETENTION "<<id<<" exact_points_and_order "<<a.points.size()<<" zero "<<a.zero<<" far "<<a.far<<"\n";}
 measure(f,id+"_N2",false,false);measure(f,id+"_N3",false,true);++count;}return count==3?0:5;}
