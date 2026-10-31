// SOURCE-PREP ONLY: constructed organized rasters, no recorded input entry point.
// Links only already-built D1 core after independent ABI/hash verification.
// Numerical validity is not normal reliability, sensor confidence or safe clearance.
#include "n2_adapter.h"
#include "../build-gate/n1_adapter.h"
#include <voxblox/core/layer.h>
#include <voxblox/core/voxel.h>
#include <voxblox/integrator/tsdf_integrator.h>
#include <voxblox/integrator/np_tsdf_integrator.h>
#include <voxblox/mesh/mesh_integrator.h>
#include <voxblox/io/mesh_ply.h>
#include <Eigen/Geometry>
#include <algorithm>
#include <cmath>
#include <iostream>
#include <iomanip>
#include <limits>
#include <stdexcept>
#include <string>
#include <set>
#include <tuple>
#include <vector>
using namespace voxblox;
namespace {
void req(bool v,const std::string&s){if(!v)throw std::runtime_error(s);}
constexpr double FX=810.82548516100394,FY=810.82548516100394,CX=366.46035766601562,CY=503.7513427734375;
// K and dimensions from original frame00001 metadata; no frame imagery loaded.
// fx=fy here: asymmetric principal point, NOT invented asymmetric focal calibration.
struct Cloud{Pointcloud p,n;Colors c;};
TsdfIntegratorBase::Config pcfg(){TsdfIntegratorBase::Config c;c.default_truncation_distance=.2;c.max_weight=10000;c.voxel_carving_enabled=true;c.min_ray_length_m=0;c.max_ray_length_m=5.055;c.use_const_weight=false;c.allow_clear=false;c.use_weight_dropoff=true;c.use_sparsity_compensation_factor=false;c.integrator_threads=1;c.integration_order_mode="mixed";c.enable_anti_grazing=false;return c;}
NpTsdfIntegratorBase::Config ncfg(bool on){NpTsdfIntegratorBase::Config c;c.default_truncation_distance=.2;c.max_weight=10000;c.voxel_carving_enabled=true;c.min_ray_length_m=0;c.max_ray_length_m=5.055;c.use_const_weight=false;c.allow_clear=false;c.use_weight_dropoff=true;c.weight_dropoff_epsilon=-1;c.use_sparsity_compensation_factor=false;c.integrator_threads=1;c.integration_order_mode="mixed";c.enable_anti_grazing=false;c.merge_with_clear=true;c.normal_available=on;c.weight_reduction_exp=2;c.reliable_band_ratio=2;c.reliable_normal_ratio_thre=.1;c.curve_assumption=false;return c;}
struct Engine{int mode;Layer<TsdfVoxel>map{.04f,16};size_t supplied=0;explicit Engine(int m):mode(m){}
 void add(const Cloud&a,const Transformation&T){req(a.p.size()==a.n.size()&&a.p.size()==a.c.size(),"input arrays");for(size_t i=0;i<a.p.size();++i)req(a.p[i].allFinite()&&a.n[i].allFinite()&&a.p[i].z()>0&&a.p[i].z()<4&&a.p[i].norm()<=5.055,"point/normal domain");if(mode==0){MergedTsdfIntegrator m(pcfg(),&map);m.integratePointCloud(T,a.p,a.c,false);}else{MergedNpTsdfIntegrator m(ncfg(mode==2),&map);m.integratePointCloud(T,a.p,a.n,a.c,false);}supplied+=a.p.size();}
 size_t gradients(){size_t n=0;BlockIndexList ids;map.getAllAllocatedBlocks(&ids);for(const auto&i:ids){auto b=map.getBlockPtrByIndex(i);for(size_t k=0;k<b->num_voxels();++k){auto&v=b->getVoxelByLinearIndex(k);req(std::isfinite(v.distance)&&std::isfinite(v.weight)&&v.gradient.allFinite(),"nonfinite mapped state");n+=v.gradient.norm()>0;}}return n;}
 Mesh mesh(){MeshLayer ml(map.block_size());MeshIntegratorConfig c;c.integrator_threads=1;c.use_color=true;c.min_weight=1e-4;MeshIntegrator<TsdfVoxel>m(c,&map,&ml);m.generateMesh(false,false);Mesh out(ml.block_size(),Point::Zero());convertMeshLayerToMesh(ml,&out,false);return out;}
};
Transformation down(float cameraHeight){Transformation::TransformationMatrix t=Transformation::TransformationMatrix::Identity();t(1,1)=-1;t(2,2)=-1;t(2,3)=cameraHeight;return Transformation(t);}
n2::Raster raster(){n2::Raster r;r.width=738;r.height=994;r.fx=FX;r.fy=FY;r.cx=CX;r.cy=CY;r.depthMm.assign(size_t(r.width)*r.height,0);return r;}
uint16_t mmFloor(double z){req(std::isfinite(z)&&z>0&&z<4,"synthetic depth range");return static_cast<uint16_t>(std::floor(z*1000.));}
// Exact 400x400 original-index ROI; no resized intrinsics. Outside is explicitly missing.
n2::Raster plane(double z,double slope=0){auto r=raster();for(int v=304;v<704;++v)for(int u=167;u<567;++u){double rx=(u-CX)/FX;r.depthMm[size_t(v)*738+u]=mmFloor(z/(1-slope*rx));}return r;}
n2::Raster geometry(const std::string&kind,double size=0){auto r=plane(1);for(int v=304;v<704;++v)for(int u=167;u<567;++u){double rx=(u-CX)/FX,ry=(v-CY)/FY;size_t i=size_t(v)*738+u;
 if(kind=="low"){double top=1-size;if(std::abs(rx*top)<=size/2&&std::abs(ry*top)<=size/2)r.depthMm[i]=mmFloor(top);}
 if(kind=="hole"&&std::abs(rx)<.15&&std::abs(ry)<.15)r.depthMm[i]=0;
 if(kind=="drop"&&std::abs(rx)<.15&&std::abs(ry)<.15)r.depthMm[i]=1400;
 }return r;}
Cloud cloud(const n2::Result&o){Cloud c;for(size_t i=0;i<o.points.size();++i){c.p.push_back(o.points[i]);c.n.push_back(o.normals[i]);c.c.emplace_back(100,80,60);}return c;}
void providerLedger(const std::string&name,const n2::Raster&r,const n2::Result&o){n1::Raster a;a.width=r.width;a.height=r.height;a.fx=r.fx;a.fy=r.fy;a.cx=r.cx;a.cy=r.cy;a.depthMm=r.depthMm;auto b=n1::compute(a);req(b.points.size()==o.points.size()&&b.pixelIndices==o.pixelIndices,"N1/N2 point count/order mismatch");for(size_t i=0;i<o.points.size();++i)req(b.points[i]==o.points[i],"N1/N2 altered unprojection");size_t total=0;for(auto n:o.counts)total+=n;req(total==o.points.size()&&o.points.size()+o.zero+o.far==r.depthMm.size(),"provider denominator");std::cout<<"{\"provider_case\":\""<<name<<"\",\"admitted\":"<<o.points.size()<<",\"zero\":"<<o.zero<<",\"far\":"<<o.far<<",\"N1_valid_numerical\":"<<b.counts[0]<<",\"N2_valid_numerical\":"<<o.counts[0]<<",\"N2_reasons\":[";for(size_t i=0;i<o.counts.size();++i){if(i)std::cout<<",";std::cout<<o.counts[i];}std::cout<<"],\"same_points_order\":true,\"calibrated_confidence\":false}"<<std::endl;}
struct GridStats{size_t total=0,observed=0,unknown=0,near=0,meshNear=0;};
GridStats sampleGrid(Engine&e,const Mesh&m,const std::string&name,float extent,float height,int count){GridStats s;std::cout<<"{\"samples\":\""<<name<<"\",\"mode\":"<<e.mode<<",\"near_threshold_m\":0.02,\"mesh_vertex_threshold_m\":0.04,\"values\":[";bool first=true;
 for(int iy=0;iy<count;++iy)for(int ix=0;ix<count;++ix){Point p(-extent+2*extent*ix/(count-1),-extent+2*extent*iy/(count-1),height);auto v=e.map.getVoxelPtrByCoordinates(p);bool observed=v&&v->weight>0;++s.total;s.observed+=observed;s.unknown+=!observed;s.near+=observed&&std::abs(v->distance)<=.02;float nearest=std::numeric_limits<float>::infinity();for(const auto&q:m.vertices)nearest=std::min(nearest,(q-p).norm());s.meshNear+=nearest<=.04;if(!first)std::cout<<",";first=false;std::cout<<"["<<p.x()<<","<<p.y()<<","<<p.z()<<","<<(observed?1:0)<<","<<(observed?v->distance:0)<<","<<(std::isfinite(nearest)?nearest:-1)<<"]";}
 std::cout<<"],\"total\":"<<s.total<<",\"observed\":"<<s.observed<<",\"unknown\":"<<s.unknown<<",\"near_zero\":"<<s.near<<",\"mesh_vertex_near\":"<<s.meshNear<<",\"complete_surface_or_clearance_claim\":false}"<<std::endl;return s;}
// Independently predeclared before execution: coarse finite-resolution nonvacuity,
// NOT triangle coverage, shape accuracy, clearance or nine independent voxels.
void retentionGate(Engine&e,const Mesh&m,const std::string&name,float extent,float height){
 const float sdfBound=.04f,vertexBound=std::sqrt(3.f)*.04f;
 size_t total=0,observed=0,sdfWithin=0,vertexWithin=0;
 std::set<std::tuple<int,int,int>> cells;
 for(int y=-1;y<=1;++y)for(int x=-1;x<=1;++x){Point q(x*extent*.5f,y*extent*.5f,height);auto id=getGridIndexFromPoint<GlobalIndex>(q,25.f);cells.emplace(id.x(),id.y(),id.z());auto v=e.map.getVoxelPtrByCoordinates(q);bool obs=v&&v->weight>0;++total;observed+=obs;sdfWithin+=obs&&std::abs(v->distance)<=sdfBound;float near=std::numeric_limits<float>::infinity();for(const auto&vert:m.vertices)near=std::min(near,(vert-q).norm());vertexWithin+=near<=vertexBound;}
 std::cout<<"{\"coarse_retention_gate\":\""<<name<<"\",\"mode\":"<<e.mode<<",\"samples\":"<<total<<",\"unique_query_voxels\":"<<cells.size()<<",\"observed\":"<<observed<<",\"sdf_within_one_voxel\":"<<sdfWithin<<",\"mesh_vertex_within_voxel_diagonal\":"<<vertexWithin<<",\"sdf_bound_m\":"<<sdfBound<<",\"vertex_bound_m\":"<<vertexBound<<",\"shape_or_safety_claim\":false}"<<std::endl;
 req(total==9&&observed==total&&sdfWithin==total&&vertexWithin==total,"predeclared coarse resolvable-surface retention gate failed");
}
void runGeometry(const std::string&name,const n2::Raster&r,float cameraHeight,float sampleHeight,float extent,bool hole=false,bool small=false){auto out=n2::compute(r);providerLedger(name,r,out);auto c=cloud(out);for(int mode=0;mode<3;++mode){Engine e(mode);e.add(c,down(cameraHeight));req(e.supplied==out.points.size(),"all pixels must reach native");auto gradients=e.gradients();if(mode==2&&name=="realK_plane_0.300000")req(gradients>0,"N2 close-plane gradient not exercised");auto mesh=e.mesh();auto s=sampleGrid(e,mesh,name+"_interior_and_boundary",extent,sampleHeight,5);if(!hole&&!small)retentionGate(e,mesh,name,extent,sampleHeight);if(hole){req(s.unknown==s.total,"large missing-support interior became observed");
 // Discrete swept-footprint samples across the hole. Independent acceptance rule
 // requires EVERY required sample to have observed near-zero support; expected false.
 bool allSupport=true;size_t unsupported=0,total=0;for(int k=0;k<=10;++k)for(int j=-1;j<=1;++j){Point p(-.20f+.04f*k,.08f*j,0);auto v=e.map.getVoxelPtrByCoordinates(p);bool ok=v&&v->weight>0&&std::abs(v->distance)<=.02;allSupport&=ok;unsupported+=!ok;++total;}req(!allSupport&&unsupported>0,"sampled footprint incorrectly supported across hole");std::cout<<"{\"sampled_swept_footprint\":\"hole\",\"mode\":"<<mode<<",\"required\":"<<total<<",\"unsupported\":"<<unsupported<<",\"admitted_as_supported\":false,\"continuous_sweep_proven\":false}"<<std::endl;}
 if(name=="actual_drop_lower_surface"){auto upper=sampleGrid(e,mesh,"drop_missing_upper_support",.06f,0,5);req(upper.near==0,"drop acquired false near-zero upper support");std::cout<<"{\"drop_upper_support\":\"not_admitted\",\"mode\":"<<mode<<",\"required_samples\":"<<upper.total<<",\"near_zero_upper_samples\":"<<upper.near<<",\"continuous_sweep_proven\":false}"<<std::endl;}
 std::cout<<"{\"geometry_summary\":\""<<name<<"\",\"mode\":"<<mode<<",\"gradient_voxels\":"<<gradients<<",\"mesh_vertices\":"<<mesh.vertices.size()<<",\"small_or_subvoxel_unresolved\":"<<(small?"true":"false")<<",\"hazard_accuracy_pass\":false}"<<std::endl;}}
void n1CloseBaseline(){auto r=plane(.3);n1::Raster b;b.width=r.width;b.height=r.height;b.fx=r.fx;b.fy=r.fy;b.cx=r.cx;b.cy=r.cy;b.depthMm=r.depthMm;auto out=n1::compute(b);auto n2out=n2::compute(r);req(out.counts[0]==0&&n2out.counts[0]>0,"close normal-policy contrast absent");req(out.pixelIndices==n2out.pixelIndices,"paired N1/N2 indices changed");Cloud c;for(size_t i=0;i<out.points.size();++i){req(out.points[i]==n2out.points[i],"paired N1/N2 point changed");c.p.push_back(out.points[i]);c.n.push_back(out.normals[i]);c.c.emplace_back(100,80,60);}Engine baseline(2);baseline.add(c,down(.3f));req(baseline.gradients()==0,"N1 close unavailable normals invented gradient");req(baseline.supplied==n2out.points.size(),"N1 close point count mismatch");auto mesh=baseline.mesh();sampleGrid(baseline,mesh,"N1_C1_close_plane_same_points_baseline",.06f,0,5);std::cout<<"{\"paired_native_baseline\":\"N1_C1_close_plane\",\"compare_to\":\"N2_C1_realK_plane_0.300000\",\"point_count\":"<<baseline.supplied<<",\"N1_valid\":0,\"N2_valid\":"<<n2out.counts[0]<<",\"accuracy_gain_claim\":false}"<<std::endl;}
void history(){auto r=plane(1,.35);auto first=n2::compute(r);providerLedger("history_tilted_first",r,first);auto c=cloud(first);for(int v=304;v<704;++v)for(int u=167;u<567;++u)if((u+v)%2)r.depthMm[size_t(v)*738+u]=0;auto second=n2::compute(r);req(second.counts[0]==0,"checkerboard must produce unavailable current normals");auto z=cloud(second);for(auto&n:z.n)req(n.norm()==0,"current normals not zero");providerLedger("history_checkerboard_second",r,second);
 Engine warm(2),fresh(2),control(1);auto T=down(1);warm.add(c,T);control.add(c,T);size_t before=warm.gradients();req(before>0,"history requires nonvacuous cached gradient");auto mat=T.getTransformationMatrix();mat(0,3)+=.005f;mat(1,3)+=.003f;Transformation shifted(mat);warm.add(z,shifted);fresh.add(z,shifted);control.add(z,shifted);req(warm.supplied==c.p.size()+z.p.size()&&fresh.supplied==z.p.size(),"history point count");size_t wg=warm.gradients(),fg=fresh.gradients(),cg=control.gradients();req(wg>0&&fg==0&&cg==0,"cached-gradient provenance violated");size_t differingWarmFresh=0,differingWarmControl=0,compared=0;float maxWF=0,maxWC=0;
 for(int y=-4;y<=4;++y)for(int x=-4;x<=4;++x){Point p(x*.04f,y*.04f,-.35f*x*.04f);auto a=warm.map.getVoxelPtrByCoordinates(p),b=fresh.map.getVoxelPtrByCoordinates(p),d=control.map.getVoxelPtrByCoordinates(p);if(a&&b&&d&&a->weight>0&&b->weight>0&&d->weight>0){++compared;float wf=std::abs(a->distance-b->distance),wc=std::abs(a->distance-d->distance);maxWF=std::max(maxWF,wf);maxWC=std::max(maxWC,wc);differingWarmFresh+=wf>1e-6f;differingWarmControl+=wc>1e-6f;}}
 req(compared>0,"history comparison has no mutually observed samples");size_t untouched=0;for(int iy=-1;iy<=1;++iy)for(int ix=-1;ix<=1;++ix){Point p(.6f+.04f*ix,.6f+.04f*iy,0);for(Engine* e:{&warm,&fresh,&control}){auto v=e->map.getVoxelPtrByCoordinates(p);req(!v||v->weight==0,"history unknown grid became observed");++untouched;}}std::cout<<"{\"history_unknown_grid\":\"preserved\",\"required_queries\":"<<untouched<<",\"native_free_or_support_claim\":false}"<<std::endl;
 std::cout<<"{\"history\":\"cached_gradient_plus_unavailable_current_normal\",\"before_gradients\":"<<before<<",\"warm_gradients\":"<<wg<<",\"fresh_gradients\":"<<fg<<",\"C0_gradients\":"<<cg<<",\"second_current_normal_valid\":0,\"compared\":"<<compared<<",\"warm_fresh_differing\":"<<differingWarmFresh<<",\"warm_C0_differing\":"<<differingWarmControl<<",\"max_distance_difference_warm_fresh\":"<<maxWF<<",\"max_distance_difference_warm_C0\":"<<maxWC<<",\"differences_attribution\":\"history_and_method_combined_not_isolated_confidence\"}"<<std::endl;
 // Sign perturbations are explicit stress controls, never additional measured confidence.
 auto neg=c,mixed=c;for(size_t i=0;i<c.n.size();++i){neg.n[i]=-neg.n[i];if(i%2)mixed.n[i]=-mixed.n[i];}Engine sign(2);sign.add(c,T);sign.add(neg,T);sign.add(mixed,shifted);auto signGrad=sign.gradients();req(sign.supplied==3*c.p.size(),"sign-view stress point loss");std::cout<<"{\"sign_view_stress\":\"positive_then_opposite_then_mixed_translated\",\"points\":"<<sign.supplied<<",\"gradient_voxels\":"<<signGrad<<",\"finite\":true,\"confidence_increase_claim\":false}"<<std::endl;
}
}
int main(int argc,char**argv){google::InitGoogleLogging(argv[0]);std::cout<<std::setprecision(9);try{req(argc==1,"constructed fixtures accept no inputs");for(double z:{.3,1.,3.})runGeometry("realK_plane_"+std::to_string(z),plane(z),float(z),0,float(z*.20));for(double s:{.02,.04,.12})runGeometry("low_top_patch_"+std::to_string(s),geometry("low",s),1,float(s),float(s*.4),false,s<=.04);runGeometry("head_overhang",plane(1),2.8f,1.8f,.20f);runGeometry("missing_floor_hole",geometry("hole"),1,0,.06f,true);runGeometry("actual_drop_lower_surface",geometry("drop"),1,-.4f,.06f);n1CloseBaseline();history();std::cout<<"{\"suite\":\"N2_native_contracts\",\"contract_checks\":\"PASS\",\"geometry_accuracy_or_safety_pass\":false,\"recorded_data\":false}"<<std::endl;return 0;}catch(const std::exception&e){std::cerr<<"FAIL "<<e.what()<<std::endl;return 2;}}
