// D1 synthetic diagnostic only. Same client source separately linked to each core.
// No native invalid inputs, recorded frames, reference data or repaired trace logic.
#include <voxblox/integrator/integrator_utils.h>
#include <voxblox/integrator/np_tsdf_integrator.h>
#include <voxblox/core/layer.h>
#include <Eigen/Core>
#include <cmath>
#include <iostream>
#include <iomanip>
#include <limits>
#include <memory>
#include <set>
#include <stdexcept>
#include <string>
#include <tuple>
#include <vector>
using namespace voxblox;
#include "expected_indices.h"
namespace {
void require(bool v,const std::string&s){if(!v)throw std::runtime_error(s);}
void point(const Point&p){std::cout<<"["<<p.x()<<","<<p.y()<<","<<p.z()<<"]";}
void indices(const std::vector<GlobalIndex>&a){std::cout<<"[";for(size_t i=0;i<a.size();++i){if(i)std::cout<<",";std::cout<<"["<<a[i].x()<<","<<a[i].y()<<","<<a[i].z()<<"]";}std::cout<<"]";}
bool equal(const std::vector<GlobalIndex>&a,const std::vector<GlobalIndex>&b){if(a.size()!=b.size())return false;for(size_t i=0;i<a.size();++i)if(a[i]!=b[i])return false;return true;}
bool bounded(const Point&p){return p.allFinite()&&p.cwiseAbs().maxCoeff()<4096.f;}
bool physicalValid(const Point&o,const Point&p,float inverse,float trunc,float maxrange,bool clearing){
 if(!bounded(o)||!bounded(p)||!std::isfinite(inverse)||inverse<=0||inverse>1000||!std::isfinite(trunc)||trunc<0||!std::isfinite(maxrange)||maxrange<=0)return false;
 Point d=p-o;float len=d.norm();if(!d.allFinite()||!std::isfinite(len)||len<=0)return false;
 if(clearing&&std::min(std::max(len-trunc,0.f),maxrange)<=0)return false;
 Point end=clearing?o+d.normalized()*std::min(std::max(len-trunc,0.f),maxrange):p+d.normalized()*trunc;
 return bounded(o*inverse)&&bounded(end*inverse);
}
std::vector<GlobalIndex> collect(RayCaster&r){std::vector<GlobalIndex>a;GlobalIndex q;while(r.nextRayIndex(&q)){a.push_back(q);require(a.size()<=256,"trace exceeded256 index cap");}require(!r.nextRayIndex(&q),"terminated trace resumed");return a;}
struct TraceSummary{size_t strictMismatch=0,exploratoryMismatch=0,originalMismatch=0;};
void trace(const ExpectedCase&c,bool candidate,TraceSummary&summary){
 require(bounded(c.start)&&bounded(c.end),"invalid scaled fixture");std::unique_ptr<RayCaster>r;Point actualStart=c.start,actualEnd=c.end;
 if(c.physical){require(physicalValid(c.origin,c.point,25,.2,5.055,false),"invalid physical fixture");Point end=c.point+(c.point-c.origin).normalized()*.2f;actualStart=c.origin*25;actualEnd=end*25;if(!c.forward)std::swap(actualStart,actualEnd);r.reset(new RayCaster(c.origin,c.point,false,true,5.055f,25.f,.2f,c.forward));}
 else r.reset(new RayCaster(c.start,c.end));
 auto actual=collect(*r);bool match=equal(actual,c.indices);std::set<std::tuple<int,int,int>> unique;for(auto&i:actual)unique.emplace(i.x(),i.y(),i.z());
 bool endpoint=!actual.empty()&&actual.back()==c.indices.back();const auto first=c.indices.front(),last=c.indices.back();int manhattan=(last-first).cwiseAbs().sum()+1;
 std::cout<<"{\"case\":\""<<c.name<<"\",\"kind\":\""<<(c.physical?"physical":"scaled")<<"\",\"strict\":"<<(c.strict?"true":"false")<<",\"start_scaled\":";point(actualStart);std::cout<<",\"end_scaled\":";point(actualEnd);std::cout<<",\"oracle_start_scaled\":";point(c.start);std::cout<<",\"oracle_end_scaled\":";point(c.end);std::cout<<",\"expected\":";indices(c.indices);std::cout<<",\"actual\":";indices(actual);std::cout<<",\"match\":"<<(match?"true":"false")<<",\"unique_count\":"<<unique.size()<<",\"manhattan_bound\":"<<manhattan<<",\"endpoint_included\":"<<(endpoint?"true":"false")<<",\"input_coordinates_finite\":true,\"internal_dda_float_state\":\"private_not_observed\"}"<<std::endl;
 if(candidate){if(c.strict&&!match){++summary.strictMismatch;require(false,"candidate strict expected-index mismatch");}else if(!c.strict&&!match)++summary.exploratoryMismatch;}
 else{
  if(!match)++summary.originalMismatch;
  const Point direction=actualEnd-actualStart;
  if(c.strict&&direction.x()!=0&&direction.y()!=0&&direction.z()!=0)require(match,"original nonzero-XYZ regression differs from geometric oracle");
  if(std::string(c.name)=="original_axis_forward")require(actual.size()==31&&unique.size()==1&&actual[0]==GlobalIndex(0,0,0),"original known axis failure changed");
  if(std::string(c.name)=="original_oblique_forward")require(match,"original oblique regression control differs from geometric oracle");
 }
}
NpTsdfIntegratorBase::Config cfg(bool on){NpTsdfIntegratorBase::Config c;c.default_truncation_distance=.2;c.max_weight=10000;c.voxel_carving_enabled=true;c.min_ray_length_m=0;c.max_ray_length_m=5.055;c.use_const_weight=false;c.allow_clear=false;c.use_weight_dropoff=true;c.weight_dropoff_epsilon=-1;c.use_sparsity_compensation_factor=false;c.integrator_threads=1;c.integration_order_mode="mixed";c.enable_anti_grazing=false;c.merge_with_clear=true;c.normal_available=on;c.weight_reduction_exp=2;c.reliable_band_ratio=2;c.reliable_normal_ratio_thre=.1;c.curve_assumption=false;return c;}
void npControl(bool candidate,bool axis){Point p=axis?Point(0,0,1):Point(.13f,.23f,1.01f);Point probe=axis?Point(.001,.001,.98):p*(.98f/1.01f);Point normal=Point(1,0,-p.x()/p.z()).normalized();float w[2]={0,0};
 std::cout<<"{\"np_case\":\""<<(axis?"original_axis":"original_oblique")<<"\",\"point\":";point(p);std::cout<<",\"probe\":";point(probe);std::cout<<",\"normal_dot_point\":"<<normal.dot(p)<<",\"off_on\":[";
 for(int on=0;on<2;++on){Layer<TsdfVoxel>layer(.04f,16);MergedNpTsdfIntegrator m(cfg(on),&layer);Pointcloud points{p},normals{normal};Colors colors{Color(1,2,3)};m.integratePointCloud(Transformation(),points,normals,colors,false);auto v=layer.getVoxelPtrByCoordinates(probe);w[on]=v?v->weight:0;require(!v||(std::isfinite(v->distance)&&std::isfinite(v->weight)&&v->gradient.allFinite()),"nonfinite probe state");if(on)std::cout<<",";std::cout<<"{\"enabled\":"<<(on?"true":"false")<<",\"allocated\":"<<(v?"true":"false")<<",\"weight\":"<<w[on]<<",\"distance\":"<<(v?v->distance:0)<<"}";}
 std::cout<<"]}"<<std::endl;
 if(candidate||!axis){require(w[0]>0,"C0 expected probe remains unobserved");require(w[1]==0,"C1 perpendicular-normal rejection missing");}else require(w[0]==0&&w[1]==0,"original axis missing-evidence baseline changed");
}
void adapterTests(){Point o=Point::Zero(),p(0,0,1),nan=p;nan.x()=std::numeric_limits<float>::quiet_NaN();Point inf=p;inf.y()=std::numeric_limits<float>::infinity();require(!physicalValid(o,o,25,.2,5.055,false),"physical zero admitted");require(!physicalValid(o,nan,25,.2,5.055,false)&&!physicalValid(o,inf,25,.2,5.055,false),"nonfinite admitted");require(!physicalValid(o,p,0,.2,5.055,false)&&!physicalValid(o,p,25,-.2,5.055,false)&&!physicalValid(o,p,25,.2,0,false),"invalid parameters admitted");require(!physicalValid(o,Point(0,0,.1),25,.2,5.055,true),"empty clearing admitted");std::cout<<"{\"adapter_validation\":\"PASS\",\"native_invalid_calls\":0,\"native_invalid_safety_claim\":false,\"empty_clear_test\":\"adapter_rejected_only\"}"<<std::endl;}
}
int main(int argc,char**argv){google::InitGoogleLogging(argv[0]);std::cout<<std::setprecision(10);try{require(argc==2,"usage client original|candidate");std::string arm=argv[1];require(arm=="original"||arm=="candidate","invalid arm");bool candidate=arm=="candidate";TraceSummary s;adapterTests();for(auto&c:expectedCases())trace(c,candidate,s);npControl(candidate,true);npControl(candidate,false);std::cout<<"{\"arm\":\""<<arm<<"\",\"strict_mismatches\":"<<s.strictMismatch<<",\"near_epsilon_diagnostic_mismatches\":"<<s.exploratoryMismatch<<",\"original_geometric_mismatches\":"<<s.originalMismatch<<",\"scope\":\"synthetic_trace_and_two_NP_controls_only\"}"<<std::endl;require(s.strictMismatch==0,"candidate strict expected-index mismatch");return 0;}catch(const std::exception&e){std::cerr<<"FAIL "<<e.what()<<std::endl;return 2;}}
