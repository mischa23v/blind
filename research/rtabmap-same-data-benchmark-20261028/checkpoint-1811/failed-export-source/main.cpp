#include <rtabmap/core/SensorData.h>
#include <rtabmap/core/CameraModel.h>
#include <rtabmap/core/Transform.h>
#include <rtabmap/core/util3d.h>
#include <rtabmap/core/util3d_transforms.h>
#include <rtabmap/core/util3d_filtering.h>
#include <rtabmap/utilite/ULogger.h>
#include <opencv2/imgcodecs.hpp>
#include <pcl/io/ply_io.h>
#include <pcl/common/point_tests.h>
#include <fstream>
#include <sstream>
#include <chrono>
#include <stdexcept>
#include <iostream>
using namespace rtabmap;
void require(bool x,const char*m){if(!x)throw std::runtime_error(m);}
void fixtures(){
 cv::Mat rgb(4,4,CV_8UC3,cv::Scalar(0,0,255));cv::Mat depth(4,4,CV_16UC1,cv::Scalar(1000));
 depth.at<unsigned short>(0,0)=0;depth.at<unsigned short>(1,1)=5000;depth.at<unsigned short>(2,2)=2000;depth.at<unsigned short>(3,3)=4000;
 CameraModel m(10,10,2,2,Transform::getIdentity(),0,cv::Size(4,4));
 SensorData d(rgb,depth,m,1,0.0);auto c=util3d::cloudRGBFromSensorData(d,1,4.0f,0.0f);
 require(c->size()==16,"fixture dimensions");require(!pcl::isFinite(c->at(0)),"missing depth excluded");require(!pcl::isFinite(c->at(5)),"far depth excluded");
 require(std::abs(c->at(10).z-2)<1e-6 && std::abs(c->at(10).x)<1e-6 &&std::abs(c->at(10).y)<1e-6,"native calibrated millimetres projection");
 require(c->at(10).r==255 &&c->at(10).b==0,"OpenCV BGR interpreted correctly");
 Transform t(1,0,0,3,0,-1,0,4,0,0,-1,5);auto w=util3d::transformPointCloud(c,t);
 require(std::abs(w->at(10).x-3)<1e-6&&std::abs(w->at(10).y-4)<1e-6&&std::abs(w->at(10).z-3)<1e-6,"known optical transform once");
 require(pcl::isFinite(c->at(15))&&std::abs(c->at(15).z-4)<1e-6,"native maxDepth includes exactly4000mm");
 CameraModel asymmetric(8,16,1,2,Transform::getIdentity(),0,cv::Size(4,4));SensorData da(rgb,depth,asymmetric,2,0.0);auto ca=util3d::cloudRGBFromSensorData(da,1,4.0f,0.0f);
 require(std::abs(ca->at(3).x-0.25f)<1e-6&&std::abs(ca->at(3).y+0.125f)<1e-6&&std::abs(ca->at(3).z-1)<1e-6,"asymmetric off-axis intrinsics");
 std::cout<<"FIXTURES_PASSED 8\n";
}
int main(int argc,char**argv){try{
 ULogger::setLevel(ULogger::kError);fixtures();if(argc==2&&std::string(argv[1])=="--fixtures")return 0;
 require(argc==4,"usage: adapter input.tsv output.ply frames.tsv");
 std::ifstream input(argv[1]);require(input.good(),"input manifest readable");std::ofstream log(argv[3]);log<<"index\tid\traster_points\tvalid_points\tvoxel_points\taccumulated_points\tseconds\n";
 auto map=pcl::PointCloud<pcl::PointXYZRGB>::Ptr(new pcl::PointCloud<pcl::PointXYZRGB>);std::string line;int n=0;
 while(std::getline(input,line)){if(line.empty())continue;auto start=std::chrono::steady_clock::now();std::istringstream s(line);std::string id,rgbpath,depthpath;int W,H;double fx,fy,cx,cy;float p[12];
 s>>id>>rgbpath>>depthpath>>W>>H>>fx>>fy>>cx>>cy;for(float&x:p)s>>x;require(bool(s),"complete manifest row");
 cv::Mat rgb=cv::imread(rgbpath,cv::IMREAD_COLOR),depth=cv::imread(depthpath,cv::IMREAD_UNCHANGED);
 require(rgb.cols==W&&rgb.rows==H&&rgb.type()==CV_8UC3,"exact RGB dimensions/type");require(depth.cols==W&&depth.rows==H&&depth.type()==CV_16UC1,"exact depth dimensions/type");
 CameraModel model(fx,fy,cx,cy,Transform::getIdentity(),0,cv::Size(W,H));SensorData data(rgb,depth,model,++n,0.0);
 std::vector<int> valid;auto cloud=util3d::cloudRGBFromSensorData(data,1,4.0f,0.0f,&valid);
 Transform pose(p[0],p[1],p[2],p[3],p[4],p[5],p[6],p[7],p[8],p[9],p[10],p[11]);
 auto world=util3d::transformPointCloud(cloud,pose);auto reduced=util3d::voxelize(world,0.04f);*map+=*reduced;
 require(map->size()<30000000,"assembled cloud cap");
 log<<n<<'\t'<<id<<'\t'<<cloud->size()<<'\t'<<valid.size()<<'\t'<<reduced->size()<<'\t'<<map->size()<<'\t'<<std::chrono::duration<double>(std::chrono::steady_clock::now()-start).count()<<'\n';log.flush();std::cout<<"FRAME "<<n<<' '<<id<<' '<<map->size()<<std::endl;
 }
 require(n==265,"all frozen training frames processed");auto result=util3d::voxelize(map,0.04f);require(!result->empty(),"nonempty result");require(pcl::io::savePLYFileBinary(argv[2],*result)==0,"pointcloud output written");std::cout<<"COMPLETE "<<n<<' '<<result->size()<<std::endl;return 0;
}catch(const std::exception&e){std::cerr<<"ERROR "<<e.what()<<std::endl;return 2;}}
