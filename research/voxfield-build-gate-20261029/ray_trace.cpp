// Separate diagnostic; preserves original NP failure, no core/assertion changes.
#include <voxblox/integrator/integrator_utils.h>
#include <voxblox/integrator/np_tsdf_integrator.h>
#include <voxblox/core/layer.h>
#include <iostream>
#include <vector>
#include <algorithm>
#include <tuple>
#include <iomanip>
using namespace voxblox;
void indices(const std::vector<GlobalIndex>& a){std::cout<<"[";for(size_t i=0;i<a.size();++i){if(i)std::cout<<",";std::cout<<"["<<a[i].x()<<","<<a[i].y()<<","<<a[i].z()<<"]";}std::cout<<"]";}
std::vector<GlobalIndex> analytic(const Point& end){
 std::vector<std::pair<double,GlobalIndex>> cells;
 GlobalIndex last=getGridIndexFromPoint<GlobalIndex>(end,25.f);
 for(int x=0;x<=last.x();++x)for(int y=0;y<=last.y();++y)for(int z=0;z<=last.z();++z){
  GlobalIndex id(x,y,z);double lo=0,hi=1;bool valid=true;
  for(int a=0;a<3;++a){if(end[a]==0){if(id[a]!=0)valid=false;}else{lo=std::max(lo,(id[a]/25.0)/double(end[a]));hi=std::min(hi,((id[a]+1)/25.0)/double(end[a]));}}
  if(valid&&lo<=hi&&hi>=0&&lo<=1)cells.emplace_back(lo,id);
 }
 std::sort(cells.begin(),cells.end(),[](const auto&a,const auto&b){return a.first<b.first;});std::vector<GlobalIndex> out;for(auto&c:cells)out.push_back(c.second);return out;
}
NpTsdfIntegratorBase::Config cfg(bool on){NpTsdfIntegratorBase::Config c;c.default_truncation_distance=.2;c.max_weight=10000;c.voxel_carving_enabled=true;c.min_ray_length_m=0;c.max_ray_length_m=5.055;c.use_const_weight=false;c.allow_clear=false;c.use_weight_dropoff=true;c.weight_dropoff_epsilon=-1;c.use_sparsity_compensation_factor=false;c.integrator_threads=1;c.integration_order_mode="mixed";c.enable_anti_grazing=false;c.merge_with_clear=true;c.normal_available=on;c.weight_reduction_exp=2;c.reliable_band_ratio=2;c.reliable_normal_ratio_thre=.1;c.curve_assumption=false;return c;}
void trace(const char*name,Point p,Point probe){Point n=Point(1,0,-p.x()/p.z()).normalized();Point end=p+p.normalized()*.2f;RayCaster rc(Point::Zero(),p,false,true,5.055f,25.f,.2f);GlobalIndex id;std::vector<GlobalIndex> actual;while(rc.nextRayIndex(&id)){actual.push_back(id);if(actual.size()>1000)throw std::runtime_error("diagnostic ray limit");}
 std::cout<<"{\"case\":\""<<name<<"\",\"point\":["<<p.x()<<","<<p.y()<<","<<p.z()<<"],\"normal_dot_point\":"<<n.dot(p)<<",\"expected_analytic_indices\":";indices(analytic(end));std::cout<<",\"actual_indices\":";indices(actual);auto q=getGridIndexFromPoint<GlobalIndex>(probe,25.f);std::cout<<",\"probe_index\":["<<q.x()<<","<<q.y()<<","<<q.z()<<"],\"normal_off_on\":[";
 for(int on=0;on<2;++on){Layer<TsdfVoxel> l(.04f,16);MergedNpTsdfIntegrator m(cfg(on),&l);Pointcloud points{p},normals{n};Colors colors{Color(1,2,3)};m.integratePointCloud(Transformation(),points,normals,colors,false);auto v=l.getVoxelPtrByCoordinates(probe);if(on)std::cout<<",";std::cout<<"{\"normal_available\":"<<(on?"true":"false")<<",\"allocated\":"<<(v?"true":"false")<<",\"weight\":"<<(v?v->weight:0)<<",\"distance\":"<<(v?v->distance:0)<<"}";}
 std::cout<<"],\"diagnostic_only\":true}"<<std::endl;
}
int main(int argc,char**argv){google::InitGoogleLogging(argv[0]);if(argc!=1)return 2;std::cout<<std::setprecision(10);trace("original_axis",Point(0,0,1),Point(.001,.001,.98));Point p(.13f,.23f,1.01f);trace("separate_oblique_nonzero_xyz",p,p*(.98f/1.01f));}
