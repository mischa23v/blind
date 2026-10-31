// Thin calibrated I/O and fixtures only. No replacement TSDF/ESDF/mesh implementation.
#include <voxblox/core/layer.h>
#include <voxblox/core/voxel.h>
#include <voxblox/integrator/tsdf_integrator.h>
#include <voxblox/integrator/esdf_integrator.h>
#include <voxblox/mesh/mesh_integrator.h>
#include <voxblox/io/mesh_ply.h>
#include <voxblox/io/layer_io.h>
#include <Eigen/Geometry>
#include <fstream>
#include <iostream>
#include <iomanip>
#include <set>
#include <stdexcept>
#include <chrono>
#include <cmath>
using namespace voxblox;
void require(bool x,const std::string& why){if(!x)throw std::runtime_error(why);}
struct Frame {std::string id,depthpath,rgbpath;int w,h;double fx,fy,cx,cy;Eigen::Matrix4d cgl;std::vector<uint16_t>d;std::vector<uint8_t>rgb;};
struct Counts {size_t zero=0,far=0,accepted=0;};
Point unproject(int u,int v,uint16_t mm,const Frame& f){double z=mm*.001;return Point(float((u-f.cx)*z/f.fx),float((v-f.cy)*z/f.fy),float(z));}
Eigen::Matrix4d opticalPose(const Frame& f){Eigen::Matrix4d flip=Eigen::Matrix4d::Identity();flip(1,1)=-1;flip(2,2)=-1;return f.cgl*flip;}
void validate(const Frame& f){require(f.w>0&&f.h>0&&f.w<=2000&&f.h<=2000,"invalid image size");require(std::isfinite(f.fx)&&std::isfinite(f.fy)&&f.fx>0&&f.fy>0&&std::isfinite(f.cx)&&std::isfinite(f.cy),"invalid K");require(f.cgl.allFinite()&&(f.cgl.row(3)-Eigen::RowVector4d(0,0,0,1)).norm()<1e-12,"invalid pose");auto R=f.cgl.block<3,3>(0,0);require((R.transpose()*R-Eigen::Matrix3d::Identity()).norm()<1e-5&&std::abs(R.determinant()-1)<1e-5,"nonrigid pose");require(f.d.size()==size_t(f.w)*f.h&&f.rgb.size()==3*f.d.size(),"buffer shape");}
Counts cloud(const Frame& f,double maxrange,Pointcloud* p,Colors* c){validate(f);Counts n;p->clear();c->clear();p->reserve(f.d.size());c->reserve(f.d.size());for(int v=0;v<f.h;++v)for(int u=0;u<f.w;++u){size_t i=size_t(v)*f.w+u;uint16_t mm=f.d[i];if(mm==0){++n.zero;continue;}if(mm>=4000){++n.far;continue;}Point q=unproject(u,v,mm,f);require(q.allFinite()&&q.norm()<=maxrange,"admitted pixel exceeds frozen ray bound");p->push_back(q);c->emplace_back(f.rgb[3*i],f.rgb[3*i+1],f.rgb[3*i+2]);++n.accepted;}require(n.zero+n.far+n.accepted==f.d.size(),"pixel denominator");return n;}
TsdfIntegratorBase::Config config(double raymax){TsdfIntegratorBase::Config c;c.default_truncation_distance=.2f;c.max_weight=10000.f;c.voxel_carving_enabled=true;c.min_ray_length_m=0.f;c.max_ray_length_m=raymax;c.use_const_weight=false;c.allow_clear=false;c.use_weight_dropoff=true;c.use_sparsity_compensation_factor=false;c.sparsity_compensation_factor=1.f;c.integrator_threads=1;c.integration_order_mode="mixed";c.enable_anti_grazing=false;return c;}
EsdfIntegrator::Config esdfConfig(){EsdfIntegrator::Config c;c.full_euclidean_distance=false;c.max_distance_m=2.;c.min_distance_m=.2;c.default_distance_m=2.;c.min_diff_m=.001;c.min_weight=1e-6;c.num_buckets=20;c.multi_queue=false;c.add_occupied_crust=false;c.clear_sphere_radius=1.5;c.occupied_sphere_radius=5.;return c;}
struct Engine {Layer<TsdfVoxel> tsdf{.04f,16};Layer<EsdfVoxel> esdf{.04f,16};MergedTsdfIntegrator integrator;std::set<std::string> seen;double raymax;explicit Engine(double r):integrator(config(r),&tsdf),raymax(r){} Counts integrate(const Frame& f){require(!seen.count(f.id),"duplicate frame ID");Pointcloud p;Colors c;auto n=cloud(f,raymax,&p,&c);auto pose=opticalPose(f);const Transformation::TransformationMatrix native_pose=pose.cast<FloatingPoint>();Transformation t(native_pose);require((t.getTransformationMatrix().cast<double>()-pose).norm()<2e-5,"native pose mismatch");integrator.integratePointCloud(t,p,c,false);seen.insert(f.id);return n;}size_t blocks(){BlockIndexList b;tsdf.getAllAllocatedBlocks(&b);return b.size();}void updateESDF(){EsdfIntegrator e(esdfConfig(),&tsdf,&esdf);e.updateFromTsdfLayerBatch();}Mesh mesh(){MeshLayer ml(tsdf.block_size());MeshIntegratorConfig c;c.integrator_threads=1;c.use_color=true;c.min_weight=1e-4;MeshIntegrator<TsdfVoxel> m(c,&tsdf,&ml);m.generateMesh(false,false);Mesh result(ml.block_size(),Point::Zero());require(convertMeshLayerToMesh(ml,&result,false),"empty native mesh");return result;}};
Frame blank(std::string id,int w,int h,double fx,double fy,double cx,double cy){Frame f;f.id=id;f.w=w;f.h=h;f.fx=fx;f.fy=fy;f.cx=cx;f.cy=cy;f.cgl=Eigen::Matrix4d::Identity();f.cgl(1,1)=-1;f.cgl(2,2)=-1;f.d.assign(size_t(w)*h,0);f.rgb.assign(3*f.d.size(),0);return f;}
void fixtures(){
 // Asymmetric K, exact integer pixel convention, millimetres, rejected domain and RGB association.
 Frame f=blank("contract",3,2,2,4,.25,.75);f.d={1000,0,4000,3999,1000,1000};for(size_t i=0;i<f.rgb.size();++i)f.rgb[i]=uint8_t(i);
 Pointcloud p;Colors c;auto n=cloud(f,10,&p,&c);require(n.accepted==4&&n.zero==1&&n.far==1,"mask counts");require((p[0]-Point(-.125f,-.1875f,1)).norm()<1e-7,"unprojection integer K units");require(c[1].r==9&&c[1].g==10&&c[1].b==11,"color index association");
 Frame changed=f;changed.fx=4;Point q=unproject(0,0,1000,changed);require(std::abs(q.x()+.0625)<1e-7,"per-frame K ignored");
 Eigen::Matrix3d R=Eigen::AngleAxisd(.4,Eigen::Vector3d::UnitZ()).toRotationMatrix();f.cgl.block<3,3>(0,0)=R;f.cgl.block<3,1>(0,3)=Eigen::Vector3d(3,4,5);Eigen::Vector4d v(.2,.3,2,1),gl(.2,-.3,-2,1);require((opticalPose(f)*v-f.cgl*gl).norm()<1e-12,"pose sign direction");
 // Off-axis z=3.999 point exceeds a 4 m RANGE but is inside axial domain.
 Frame edge=blank("offaxis",1,1,1,1,-1,0);edge.d[0]=3999;cloud(edge,6,&p,&c);require(p.size()==1&&p[0].norm()>4,"axial/ray distinction");
 Layer<TsdfVoxel> denied(.04f,16),cleared(.04f,16);auto cf=config(4);MergedTsdfIntegrator di(cf,&denied);di.integratePointCloud(Transformation(),p,c,false);BlockIndexList db;denied.getAllAllocatedBlocks(&db);require(db.empty(),"allow_clear=false failed native out-of-range rejection");cf.allow_clear=true;MergedTsdfIntegrator ci(cf,&cleared);ci.integratePointCloud(Transformation(),p,c,false);cleared.getAllAllocatedBlocks(&db);require(!db.empty(),"native clear control did not carve");
 Engine e(10);Frame plane=blank("plane",65,65,64,64,32,32);std::fill(plane.d.begin(),plane.d.end(),1000);for(size_t i=0;i<plane.rgb.size();i+=3){plane.rgb[i]=120;plane.rgb[i+1]=40;plane.rgb[i+2]=10;}e.integrate(plane);auto near=e.tsdf.getVoxelPtrByCoordinates(Point(.02,.02,.98));require(near&&near->weight>0&&std::abs(near->distance)<.06,"known native plane TSDF");auto mesh=e.mesh();require(mesh.vertices.size()>0,"known plane mesh");for(auto x:mesh.vertices)require(std::abs(x.z()-1)<.07,"mesh units/plane location");size_t before=e.blocks();bool duplicate=false;try{e.integrate(plane);}catch(const std::runtime_error&x){duplicate=std::string(x.what())=="duplicate frame ID";}require(duplicate&&before==e.blocks(),"duplicate accepted");
 // Three observed front patches in Z-up world; missing bands stay unknown, not invented floor/free support.
 Engine hazards(10);Frame h=blank("hazards",101,101,50,50,50,50);Eigen::Matrix4d T=Eigen::Matrix4d::Identity();T.block<3,3>(0,0)<<1,0,0,0,0,1,0,-1,0;T(2,3)=1;Eigen::Matrix4d flip=Eigen::Matrix4d::Identity();flip(1,1)=-1;flip(2,2)=-1;h.cgl=T*flip;
 for(int v0:{5,45,85})for(int v1=v0;v1<=v0+10;++v1)for(int u=40;u<=60;++u)h.d[v1*h.w+u]=1000;
 hazards.integrate(h);auto hm=hazards.mesh();bool low=false,head=false;for(auto x:hm.vertices){low|=x.z()<.35;head|=x.z()>1.65;}require(low&&head,"low/head surface lost");Point missing(.02,1.02,.5);auto unknown=hazards.tsdf.getVoxelPtrByCoordinates(missing);require(!unknown||unknown->weight==0,"missing band became observed TSDF");hazards.updateESDF();auto eu=hazards.esdf.getVoxelPtrByCoordinates(missing);require(!eu||!eu->observed,"unknown/drop band became observed ESDF");
 Engine floorhole(10);Frame ground=blank("floor_hole",65,65,64,64,32,32);ground.cgl=Eigen::Matrix4d::Identity();ground.cgl(2,3)=1;std::fill(ground.d.begin(),ground.d.end(),1000);for(int v1=21;v1<=43;++v1)for(int u=21;u<=43;++u)ground.d[v1*ground.w+u]=0;floorhole.integrate(ground);auto supported=floorhole.tsdf.getVoxelPtrByCoordinates(Point(.30,.02,.02));require(supported&&supported->weight>0&&std::abs(supported->distance)<.06,"observed floor patch absent");Point drop(.02,.02,.02);auto absent=floorhole.tsdf.getVoxelPtrByCoordinates(drop);require(!absent||absent->weight==0,"missing floor/drop region invented TSDF support");floorhole.updateESDF();auto de=floorhole.esdf.getVoxelPtrByCoordinates(drop);require(!de||!de->observed,"missing floor/drop region invented observed ESDF");
 Engine empty(10);Frame zeros=blank("zeros",5,5,4,4,2,2);empty.integrate(zeros);require(empty.blocks()==0,"missing pixels carved free blocks");
 std::cout<<"{\"fixtures\":\"PASS\",\"checks\":[\"integer_pixel_asymmetric_K\",\"millimetres_mask\",\"RGB_association\",\"changing_K\",\"Cgl_optical_pose\",\"offaxis_axial_vs_range\",\"native_allow_clear_control\",\"native_plane_TSDF_mesh\",\"duplicate_rejection\",\"native_low_head_retention\",\"unknown_drop_band_TSDF_ESDF\",\"floor_hole_unknown_not_support\",\"zero_depth_no_carving\"]}"<<std::endl;
}
int main(){try{google::InitGoogleLogging("old13_fixtures");fixtures();return 0;}catch(const std::exception&e){std::cerr<<"FAIL: "<<e.what()<<std::endl;return 2;}}
