#include <rtabmap/core/DBDriver.h>
#include <rtabmap/core/SensorData.h>
#include <rtabmap/core/CameraModel.h>
#include <rtabmap/core/util3d.h>
#include <rtabmap/core/util3d_transforms.h>
#include <rtabmap/core/util3d_filtering.h>
#include <pcl/io/ply_io.h>
#include <fstream>
#include <sstream>
#include <iostream>
#include <memory>
using namespace rtabmap;
int main(int argc,char**argv){if(argc!=4)return 2;std::unique_ptr<DBDriver> db(DBDriver::create());if(!db->openConnection(argv[1],false,true))return 3;std::ifstream poses(argv[2]);std::string line;int count=0;auto all=pcl::PointCloud<pcl::PointXYZRGB>::Ptr(new pcl::PointCloud<pcl::PointXYZRGB>);
while(std::getline(poses,line)){std::istringstream s(line);int id;float p[12];s>>id;for(float&v:p)s>>v;if(!s)return 4;SensorData data;db->getNodeData(id,data,true,false,false,true);cv::Mat rgb,depth;data.uncompressData(&rgb,&depth);std::cout<<id<<" rgb="<<rgb.cols<<"x"<<rgb.rows<<" depth="<<depth.cols<<"x"<<depth.rows<<" models="<<data.cameraModels().size()<<std::endl;if(rgb.empty()||depth.empty()||data.cameraModels().size()!=1)return 5;
pcl::IndicesPtr valid(new std::vector<int>);auto c=util3d::cloudRGBFromSensorData(data,1,4,0,valid.get());Transform optical(p[0],p[1],p[2],p[3],p[4],p[5],p[6],p[7],p[8],p[9],p[10],p[11]);auto w=util3d::transformPointCloud(c,optical*data.cameraModels()[0].localTransform().inverse());auto v=util3d::voxelize(w,valid,0.04f);*all+=*v;++count;}
if(count!=265||all->empty())return 6;auto result=util3d::voxelize(all,0.04f);std::cout<<"COMPLETE "<<count<<" points="<<result->size()<<std::endl;return pcl::io::savePLYFileBinary(argv[3],*result);}
