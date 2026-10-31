#include <rtabmap/core/Rtabmap.h>
#include <rtabmap/core/Signature.h>
#include <rtabmap/core/SensorData.h>
#include <rtabmap/core/CameraModel.h>
#include <rtabmap/core/Transform.h>
#include <rtabmap/core/Parameters.h>
#include <rtabmap/core/util3d.h>
#include <rtabmap/core/util3d_transforms.h>
#include <rtabmap/core/util3d_filtering.h>
#include <rtabmap/utilite/ULogger.h>
#include <opencv2/imgcodecs.hpp>
#include <pcl/io/ply_io.h>
#include <fstream>
#include <sstream>
#include <chrono>
#include <stdexcept>
#include <iostream>
#include <iomanip>
#include <filesystem>
using namespace rtabmap;
void require(bool x,const char*m){if(!x)throw std::runtime_error(m);}
int main(int argc,char**argv){try{
 require(argc==4,"usage: mapper input.tsv output-directory fixed|graph");std::string out=argv[2],mode=argv[3];require(mode=="fixed"||mode=="graph","mode");
 ULogger::setLevel(ULogger::kWarning);
 auto params=Parameters::getDefaultParameters();
 params["Rtabmap/DetectionRate"]="0";params["RGBD/Enabled"]="true";params["RGBD/LinearUpdate"]="0";params["RGBD/AngularUpdate"]="0";params["Mem/RehearsalSimilarity"]="1";params["Mem/STMSize"]="10";
 params["Kp/DetectorStrategy"]="2";params["Vis/FeatureType"]="2";params["Kp/MaxFeatures"]="500";params["Vis/MaxFeatures"]="500";
 params["RGBD/CreateOccupancyGrid"]="true";params["Grid/Sensor"]="1";params["Grid/3D"]="true";params["Grid/CellSize"]="0.04";params["Grid/RangeMax"]="4";params["Grid/DepthDecimation"]="1";params["Grid/MapFrameProjection"]="true";
 params["Optimizer/Strategy"]="0";
 if(mode=="fixed"){params["Optimizer/Iterations"]="0";params["Rtabmap/LoopThr"]="1";params["RGBD/AggressiveLoopThr"]="1";params["RGBD/ProximityByTime"]="false";params["RGBD/ProximityBySpace"]="false";}
 else{params["Optimizer/Iterations"]="100";}
 std::ofstream config(out+"/PARAMETERS.tsv");for(const auto&kv:params)config<<kv.first<<'\t'<<kv.second<<'\n';config.close();
 require(!std::filesystem::exists(out+"/map.db"),"fresh output database required");
 Rtabmap mapper;mapper.init(params,out+"/map.db",false);
 std::ifstream input(argv[1]);require(input.good(),"input readable");std::ofstream log(out+"/FRAMES.tsv");log<<"index\tid\taccepted\tloopClosureID\tdepthExactly4000Pixels\tseconds\n";
 Transform flip(1,0,0,0,0,-1,0,0,0,0,-1,0);const auto A=Transform::rtabmap_T_opengl(),B=Transform::opengl_T_rtabmap(),O=CameraModel::opticalRotation();
 // Native convention identity: B*O equals optical->OpenGL axis flip.
 auto probe=B*O;for(int r=0;r<3;++r)for(int c=0;c<4;++c)require(std::abs(probe(r,c)-flip(r,c))<1e-6,"native optical/world basis identity");
 std::string line;int n=0,accepted=0;std::map<int,Transform> supplied;
 while(std::getline(input,line)){if(line.empty())continue;auto start=std::chrono::steady_clock::now();std::istringstream s(line);std::string id,rgbpath,depthpath;int W,H;double fx,fy,cx,cy;float p[12];s>>id>>rgbpath>>depthpath>>W>>H>>fx>>fy>>cx>>cy;for(float&x:p)s>>x;require(bool(s),"manifest row");
 cv::Mat rgb=cv::imread(rgbpath,cv::IMREAD_COLOR),depth=cv::imread(depthpath,cv::IMREAD_UNCHANGED);require(rgb.cols==W&&rgb.rows==H&&rgb.type()==CV_8UC3,"RGB raster");require(depth.cols==W&&depth.rows==H&&depth.type()==CV_16UC1,"depth raster");
 Transform opticalPose(p[0],p[1],p[2],p[3],p[4],p[5],p[6],p[7],p[8],p[9],p[10],p[11]);Transform nodePose=opticalPose*O.inverse();
 CameraModel model(fx,fy,cx,cy,O,0,cv::Size(W,H));SensorData data(rgb,depth,model,++n,0.0);supplied[n]=opticalPose;bool ok=mapper.process(data,nodePose);accepted+=ok;
 log<<n<<'\t'<<id<<'\t'<<ok<<'\t'<<mapper.getLoopClosureId()<<'\t'<<cv::countNonZero(depth==4000)<<'\t'<<std::chrono::duration<double>(std::chrono::steady_clock::now()-start).count()<<'\n';log.flush();std::cout<<"FRAME "<<n<<' '<<id<<' '<<ok<<std::endl;
 }
 require(n==265,"scheduled265frames");std::map<int,Transform> poses;std::multimap<int,Link> constraints;std::map<int,Signature> signatures;
 mapper.getGraph(poses,constraints,mode=="graph",true,&signatures,true,false,false,true,false,false);
 std::ofstream graph(out+"/POSES.tsv"),grid(out+"/LOCAL_GRID_COUNTS.tsv");grid<<"node\tground\tobstacles\tempty\n";
 auto map=pcl::PointCloud<pcl::PointXYZRGB>::Ptr(new pcl::PointCloud<pcl::PointXYZRGB>);
 for(const auto&kv:poses){int id=kv.first;if(id<=0)continue;auto it=signatures.find(id);require(it!=signatures.end(),"graph node must have exported signature");require(supplied.count(id)==1,"graph node must match supplied input");SensorData data=it->second.sensorData();data.uncompressData();auto optical=kv.second*O;
 if(mode=="fixed")for(int r=0;r<3;++r)for(int c=0;c<4;++c)require(std::abs(optical(r,c)-supplied.at(id)(r,c))<1e-4,"fixed exported optical pose equals supplied pose");
 graph<<id;for(int r=0;r<3;++r)for(int c=0;c<4;++c)graph<<'\t'<<std::setprecision(9)<<optical(r,c);graph<<'\n';
 grid<<id<<'\t'<<data.gridGroundCellsRaw().total()<<'\t'<<data.gridObstacleCellsRaw().total()<<'\t'<<data.gridEmptyCellsRaw().total()<<'\n';
 pcl::IndicesPtr valid(new std::vector<int>);auto cloud=util3d::cloudRGBFromSensorData(data,1,4.0f,0.0f,valid.get());auto world=util3d::transformPointCloud(cloud,kv.second);auto reduced=util3d::voxelize(world,valid,0.04f);*map+=*reduced;require(map->size()<30000000,"cloudcap");
 }
 auto result=util3d::voxelize(map,0.04f);require(!result->empty(),"nonempty enginecloud");require(pcl::io::savePLYFileBinary(out+"/cloud.ply",*result)==0,"cloudwrite");mapper.close(true);
 std::ofstream receipt(out+"/ENGINE_RESULT.txt");receipt<<"mode="<<mode<<"\nscheduled="<<n<<"\nprocessAccepted="<<accepted<<"\nposes="<<poses.size()<<"\nsignatures="<<signatures.size()<<"\nconstraints="<<constraints.size()<<"\ncloudPoints="<<result->size()<<"\n";std::cout<<"COMPLETE "<<n<<' '<<accepted<<' '<<poses.size()<<std::endl;return 0;
}catch(const std::exception&e){std::cerr<<"ERROR "<<e.what()<<std::endl;return 2;}}
