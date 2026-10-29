// Synthetic-only Voxfield integration contracts. No recorded-data entry point.
// Point-derived normals use forward cross products; explicit synthetic normals
// are used only for isolated zero/sign/grazing integrator controls.
#include "n1_adapter.h"
#include <voxblox/core/layer.h>
#include <voxblox/core/voxel.h>
#include <voxblox/integrator/tsdf_integrator.h>
#include <voxblox/integrator/np_tsdf_integrator.h>
#include <voxblox/integrator/esdf_integrator.h>
#include <voxblox/mesh/mesh_integrator.h>
#include <voxblox/io/mesh_ply.h>
#include <voxblox/io/layer_io.h>
#include <Eigen/Geometry>
#include <cmath>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string>
#include <vector>
using namespace voxblox;
namespace {
void req(bool b,const std::string&s){if(!b)throw std::runtime_error(s);}
void pass(const std::string&s){std::cout<<"{\"check\":\""<<s<<"\",\"status\":\"PASS\"}"<<std::endl;}
struct Cloud{Pointcloud p,n;Colors c;};
TsdfIntegratorBase::Config pcfg(){TsdfIntegratorBase::Config c;c.default_truncation_distance=.2f;c.max_weight=10000;c.voxel_carving_enabled=true;c.min_ray_length_m=0;c.max_ray_length_m=5.055;c.use_const_weight=false;c.allow_clear=false;c.use_weight_dropoff=true;c.use_sparsity_compensation_factor=false;c.integrator_threads=1;c.integration_order_mode="mixed";c.enable_anti_grazing=false;return c;}
NpTsdfIntegratorBase::Config ncfg(bool enabled){NpTsdfIntegratorBase::Config c;c.default_truncation_distance=.2f;c.max_weight=10000;c.voxel_carving_enabled=true;c.min_ray_length_m=0;c.max_ray_length_m=5.055;c.use_const_weight=false;c.allow_clear=false;c.use_weight_dropoff=true;c.weight_dropoff_epsilon=-1;c.use_sparsity_compensation_factor=false;c.integrator_threads=1;c.integration_order_mode="mixed";c.enable_anti_grazing=false;c.merge_with_clear=true;c.normal_available=enabled;c.weight_reduction_exp=2;c.reliable_band_ratio=2;c.reliable_normal_ratio_thre=.1;c.curve_assumption=false;return c;}
struct Engine{
 Layer<TsdfVoxel> t{.04f,16};Layer<EsdfVoxel> e{.04f,16};int mode;size_t supplied=0;
 explicit Engine(int m):mode(m){}
 void add(const Cloud&a,const Transformation&T=Transformation()){
  req(a.p.size()==a.n.size()&&a.p.size()==a.c.size(),"array length precondition");
  for(size_t i=0;i<a.p.size();++i){req(a.p[i].allFinite()&&a.n[i].allFinite(),"nonfinite input precondition");req(a.p[i].z()>0&&a.p[i].z()<4&&a.p[i].norm()<=5.055,"synthetic depth/range contract");}
  const auto count=a.p.size();
  if(mode==0){MergedTsdfIntegrator m(pcfg(),&t);m.integratePointCloud(T,a.p,a.c,false);}
  else{MergedNpTsdfIntegrator m(ncfg(mode==2),&t);m.integratePointCloud(T,a.p,a.n,a.c,false);}
  req(a.p.size()==count&&a.n.size()==count,"input point count changed");supplied+=count;
 }
 void finite(){BlockIndexList ids;t.getAllAllocatedBlocks(&ids);for(const auto&i:ids){auto b=t.getBlockPtrByIndex(i);for(size_t j=0;j<b->num_voxels();++j){auto&v=b->getVoxelByLinearIndex(j);req(std::isfinite(v.distance)&&std::isfinite(v.weight)&&v.gradient.allFinite(),"nonfinite TSDF state");}}}
 void esdf(){EsdfIntegrator::Config c;c.full_euclidean_distance=false;c.max_distance_m=2;c.min_distance_m=.2;c.default_distance_m=2;c.min_diff_m=.001;c.min_weight=1e-6;c.num_buckets=20;c.multi_queue=false;c.add_occupied_crust=false;EsdfIntegrator m(c,&t,&e);m.updateFromTsdfLayerBatch();}
 Mesh mesh(){MeshLayer ml(t.block_size());MeshIntegratorConfig c;c.integrator_threads=1;c.use_color=true;c.min_weight=1e-4;MeshIntegrator<TsdfVoxel> m(c,&t,&ml);m.generateMesh(false,false);Mesh result(ml.block_size(),Point::Zero());req(convertMeshLayerToMesh(ml,&result,false),"empty synthetic mesh");return result;}
};
Cloud plane(float slope=0){Cloud a;const int N=65;Pointcloud raster;for(int v=0;v<N;++v)for(int u=0;u<N;++u){float x=(u-32)/64.f,y=(v-32)/64.f,z=1+slope*x;raster.emplace_back(x,y,z);}
 for(int v=0;v<N;++v)for(int u=0;u<N;++u){const int k=v*N+u;a.p.push_back(raster[k]);Point n=Point::Zero();if(u+1<N&&v+1<N){auto cross=(raster[k+1]-raster[k]).cross(raster[k+N]-raster[k]);req(cross.norm()>kEpsilon,"synthetic plane degeneracy");n=cross.normalized();}a.n.push_back(n);a.c.emplace_back(120,40,10);}return a;}
Transformation zup(){Transformation::TransformationMatrix m=Transformation::TransformationMatrix::Identity();m.block<3,3>(0,0)<<1,0,0,0,0,1,0,-1,0;m(2,3)=1;return Transformation(m);}
Transformation down(){Transformation::TransformationMatrix m=Transformation::TransformationMatrix::Identity();m(1,1)=-1;m(2,2)=-1;m(2,3)=1;return Transformation(m);}
Cloud patches(){Cloud a;for(int v0:{5,45,85})for(int v=v0;v<=v0+10;++v)for(int u=40;u<=60;++u){a.p.emplace_back((u-50)/50.f,(v-50)/50.f,1);a.n.emplace_back(0,0,1);a.c.emplace_back(80,90,100);}return a;}
Cloud floor(bool actualDrop){Cloud a;for(int v=0;v<65;++v)for(int u=0;u<65;++u){bool hole=u>=21&&u<=43&&v>=21&&v<=43;if(hole&&!actualDrop)continue;float z=hole?1.4f:1.f;a.p.emplace_back((u-32)*z/64,(v-32)*z/64,z);a.n.emplace_back(0,0,1);a.c.emplace_back(90,90,90);}return a;}
void unknown(Engine&e,const Point&q){auto v=e.t.getVoxelPtrByCoordinates(q);req(!v||v->weight==0,"unknown patch acquired TSDF evidence");e.esdf();auto d=e.e.getVoxelPtrByCoordinates(q);req(!d||!d->observed,"unknown patch acquired ESDF observation");}
void modeFixtures(int mode){const std::string tag=mode==0?"B":mode==1?"C0":"C1";
 {Engine e(mode);auto a=plane(.3f);e.add(a);e.finite();req(e.supplied==4225,"sloped plane input count");auto v=e.t.getVoxelPtrByCoordinates(Point(.02,.02,1.02));req(v&&v->weight>0&&std::abs(v->distance)<.08,"sloped plane near surface missing");if(mode==2)req(v->gradient.norm()>.5,"enabled NP gradient absent");else req(v->gradient.norm()==0,"disabled gradient changed");auto m=e.mesh();for(auto p:m.vertices)req(std::abs(p.z()-(1+.3f*p.x()))<.09,"sloped plane mesh displaced");pass(tag+"_point_derived_sloped_plane_and_count");}
 {Engine e(mode);Cloud a=patches();e.add(a,zup());e.finite();auto m=e.mesh();bool low=false,head=false;for(auto p:m.vertices){low|=p.z()<.35;head|=p.z()>1.65;}req(low&&head,"low/head patch disappeared");unknown(e,Point(.02,1.02,.5));pass(tag+"_low_head_retention_unknown_band");}
 {Engine e(mode);e.add(floor(false),down());auto s=e.t.getVoxelPtrByCoordinates(Point(.30,.02,.02));req(s&&s->weight>0&&std::abs(s->distance)<.06,"floor support patch absent");unknown(e,Point(.02,.02,.02));pass(tag+"_floor_hole_unknown");}
 {Engine e(mode);e.add(floor(true),down());e.finite();auto below=e.t.getVoxelPtrByCoordinates(Point(.02,.02,-.38));req(below&&below->weight>0&&std::abs(below->distance)<.07,"actual lower floor missing");auto rim=e.t.getVoxelPtrByCoordinates(Point(.02,.02,.02));req(!rim||rim->weight==0||rim->distance>.15,"actual drop bridged as floor");pass(tag+"_actual_drop_not_bridged");}
 // A true horizontal overhang is a downward-facing observed patch, not a height-map collapse.
 {Engine e(mode);auto a=plane();auto T=down();auto mat=T.getTransformationMatrix();mat(2,3)=2.8f;e.add(a,Transformation(mat));auto m=e.mesh();bool overhang=false;for(auto p:m.vertices)overhang|=p.z()>1.7&&p.z()<1.9;req(overhang,"horizontal overhang lost");unknown(e,Point(.02,.02,.5));pass(tag+"_horizontal_overhang_unknown_below");}
 {Engine e(mode);Cloud a;for(int v=75;v<=90;++v)for(int u=-6;u<=6;++u){a.p.emplace_back(u*.01f,v*.01f,1);a.n.emplace_back(0,0,1);a.c.emplace_back(100,60,20);}e.add(a,zup());e.finite();auto m=e.mesh();bool thinlow=false;for(auto p:m.vertices)thinlow|=std::abs(p.x())<.09&&p.z()<.30;req(thinlow,"12cm-wide low patch lost");pass(tag+"_thin_low_obstacle_retention");}
 {Engine e(mode);Cloud a;e.add(a);BlockIndexList b;e.t.getAllAllocatedBlocks(&b);req(b.empty(),"empty observation carved blocks");pass(tag+"_empty_unknown");}
}
void n1EndToEnd(){
 for(bool hole:{false,true}){
  n1::Raster raster;raster.width=65;raster.height=65;raster.fx=64;raster.fy=64;raster.cx=32;raster.cy=32;raster.depthMm.assign(4225,1000);
  if(hole)for(int v=21;v<=43;++v)for(int u=21;u<=43;++u)raster.depthMm[size_t(v)*65+u]=0;
  const auto observed=n1::compute(raster);Cloud a;
  req(observed.points.size()==size_t(hole?3696:4225),"N1 end-to-end point preservation");
  req(observed.points.size()==observed.normals.size()&&observed.points.size()==observed.reasons.size(),"N1 end-to-end array shape");
  size_t valid=0,unavailable=0;size_t previous=0;
  for(size_t i=0;i<observed.points.size();++i){
   req(i==0||observed.pixelIndices[i]>previous,"N1 end-to-end ordering");previous=observed.pixelIndices[i];
   a.p.push_back(observed.points[i]);a.n.push_back(observed.normals[i]);a.c.emplace_back(120,40,10);
   if(observed.reasons[i]==n1::Reason::Valid){++valid;req(observed.normals[i].z()>.99,"N1 end-to-end +z sign");}
   else{++unavailable;req(observed.normals[i].norm()==0,"N1 unavailable normal is not zero");}
  }
  req(valid>0&&unavailable>0,"N1 validity reasons not exercised");
  req(valid+unavailable==a.p.size(),"N1 reason denominator");
  Engine e(2);e.add(a,hole?down():Transformation());e.finite();req(e.supplied==a.p.size(),"N1 C1 admitted count changed");
  auto near=e.t.getVoxelPtrByCoordinates(hole?Point(.30,.02,.02):Point(.02,.02,.98));
  req(near&&near->weight>0&&std::abs(near->distance)<.06,"N1 C1 observed plane absent");
  if(hole){req(observed.zero==529,"N1 hole invalid-pixel denominator");unknown(e,Point(.02,.02,.02));}
  else{auto m=e.mesh();for(const auto&p:m.vertices)req(std::abs(p.z()-1)<.07,"N1 C1 plane mesh displaced");}
  pass(hole?"N1_raster_to_C1_hole_unknown_all_points_retained":"N1_raster_to_C1_plane_sign_all_points_retained");
 }
}
void normalControls(){auto a=plane(.3f);Cloud opposite=a,zero=a;for(auto&n:opposite.n)n=-n;for(auto&n:zero.n)n.setZero();Engine pos(2),neg(2),none(2);pos.add(a);neg.add(opposite);none.add(zero);pos.finite();neg.finite();none.finite();BlockIndexList ids;pos.t.getAllAllocatedBlocks(&ids);size_t compared=0;for(auto&i:ids){auto p=pos.t.getBlockPtrByIndex(i),n=neg.t.getBlockPtrByIndex(i);req(bool(n),"opposite normals changed block set");for(size_t j=0;j<p->num_voxels();++j){const auto&x=p->getVoxelByLinearIndex(j);const auto&y=n->getVoxelByLinearIndex(j);req(std::abs(x.distance-y.distance)<1e-5&&std::abs(x.weight-y.weight)<1e-5,"opposite normals changed unsigned-incidence TSDF");++compared;}}req(compared>0,"sign control compared nothing");auto q=none.t.getVoxelPtrByCoordinates(Point(.02,.02,1.02));req(q&&q->weight>0&&q->gradient.norm()==0,"zero normal fallback lost point or invented gradient");pass("C1_zero_and_opposite_normals_finite_sign_control");
 // Isolated single ray with a perpendicular synthetic normal: near-surface update rejected.
 Cloud ray;ray.p.emplace_back(0,0,1);ray.n.emplace_back(1,0,0);ray.c.emplace_back(1,2,3);Engine off(1),on(2);off.add(ray);on.add(ray);auto v0=off.t.getVoxelPtrByCoordinates(Point(.001,.001,.98)),v1=on.t.getVoxelPtrByCoordinates(Point(.001,.001,.98));req(v0&&v0->weight>0,"grazing control missing disabled observation");req(!v1||v1->weight==0,"grazing rejection absent");on.finite();pass("C0_C1_grazing_rejection_not_free_proof");
 req(io::SaveLayer(pos.t,"synthetic_gradient_loss.voxblox"),"native save failed");Layer<TsdfVoxel>::Ptr reloaded;req(io::LoadLayer<TsdfVoxel>("synthetic_gradient_loss.voxblox",&reloaded),"native reload failed");bool had=false;for(auto&i:ids){auto p=pos.t.getBlockPtrByIndex(i),r=reloaded->getBlockPtrByIndex(i);req(bool(r),"reload block absent");for(size_t j=0;j<p->num_voxels();++j){auto&x=p->getVoxelByLinearIndex(j);auto&y=r->getVoxelByLinearIndex(j);had|=x.gradient.norm()>.5;req(x.distance==y.distance&&x.weight==y.weight,"reload changed serialized state");req(y.gradient.norm()==0,"unexpected gradient serialization behavior");}}req(had,"gradient loss control had no gradients");pass("native_serialization_gradient_loss_documented_no_resume");
 // Adapter precondition validation occurs before native calls (native CHECK abort is not suppressed).
 Engine bad(2);auto malformed=a;malformed.n.pop_back();bool caught=false;try{bad.add(malformed);}catch(const std::runtime_error&){caught=true;}req(caught&&bad.supplied==0,"mismatched normals accepted");malformed=a;malformed.n[0].x()=std::numeric_limits<float>::quiet_NaN();caught=false;try{bad.add(malformed);}catch(const std::runtime_error&){caught=true;}req(caught&&bad.supplied==0,"nonfinite normals accepted");pass("normal_array_nonfinite_preconditions");
}
}
int main(int argc,char**argv){google::InitGoogleLogging(argv[0]);try{req(argc==1,"synthetic executable accepts no inputs");for(int m=0;m<3;++m)modeFixtures(m);n1EndToEnd();normalControls();std::cout<<"{\"suite\":\"NP synthetic integration\",\"status\":\"PASS\",\"recordedData\":false}"<<std::endl;return 0;}catch(const std::exception&e){std::cerr<<"{\"suite\":\"NP synthetic integration\",\"status\":\"FAIL\",\"reason\":\""<<e.what()<<"\"}"<<std::endl;return 2;}}
