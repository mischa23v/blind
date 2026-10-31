#include <rtabmap/core/LocalGridMaker.h>
#include <rtabmap/core/CameraModel.h>
#include <rtabmap/core/util3d.h>
#include <rtabmap/core/util3d_transforms.h>
#include <iostream>
#include <fstream>
#include <stdexcept>
using namespace rtabmap;
void need(bool v,const char*m){if(!v)throw std::runtime_error(m);}
int main(int argc,char**argv){try{need(argc==2,"parameter file");ParametersMap p;std::ifstream f(argv[1]);std::string l;while(std::getline(f,l)){auto k=l.find('\t');p[l.substr(0,k)]=l.substr(k+1);}need(p["Grid/RayTracing"]=="false","classifier ray tracing unchanged");auto O=CameraModel::opticalRotation();Transform P(0,0,1,3,-1,0,0,4,0,-1,0,1.6);auto node=P*O.inverse();auto back=node*O;for(int r=0;r<3;++r)for(int c=0;c<4;++c)need(std::abs(back(r,c)-P(r,c))<1e-6,"Z-up world pose roundtrip");pcl::PointXYZ optical(.2,.3,2);auto local=util3d::transformPoint(optical,O);auto world=util3d::transformPoint(local,node);need(std::abs(world.x-5)<1e-5&&std::abs(world.y-3.8)<1e-5&&std::abs(world.z-1.3)<1e-5,"asymmetric native world point");
 pcl::PointCloud<pcl::PointXYZ> floor;for(int i=0;i<20;++i)for(int j=0;j<20;++j)floor.push_back(pcl::PointXYZ(.5+i*.04,-.4+j*.04,0));auto scan=util3d::laserScanFromPointCloud(floor);LocalGridMaker maker(p);cv::Mat ground,obstacles,empty;cv::Point3f viewpoint(0,0,1.6);maker.createLocalMap(scan,Transform::getIdentity(),ground,obstacles,empty,viewpoint);need(ground.cols>0,"native world Z-up plane yields ground");need(obstacles.empty(),"analytic horizontal floor not obstacle");need(empty.empty(),"classifier no invented free rays");std::cout<<"WORLD_ZUP_NATIVE_FIXTURES_PASSED floorGround="<<ground.cols<<" obstacles="<<obstacles.cols<<std::endl;return 0;}catch(const std::exception&e){std::cerr<<e.what()<<std::endl;return 2;}}
