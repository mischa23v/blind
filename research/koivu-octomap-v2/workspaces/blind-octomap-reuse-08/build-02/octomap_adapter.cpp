// Simulation-only adapter. Upstream OctoMap owns occupancy updates and ray traversal.
#include <octomap/octomap.h>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <memory>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <vector>
struct Counts { uint32_t hits=0, frees=0; };
struct Handle { octomap::OcTree tree; std::unordered_map<uint64_t,Counts> evidence; uint64_t next=0; bool healthy=true; explicit Handle(double r):tree(r){} };
struct ScanStats { uint64_t frame, originalPoints, occupiedKeys, representativeRays, freeKeys, treeNodes, conflictKeys; };
static thread_local std::string error;
static uint64_t packed(const octomap::OcTreeKey& k){return (uint64_t(k[0])<<32)|(uint64_t(k[1])<<16)|uint64_t(k[2]);}
static bool finite3(const float*p){return p&&std::isfinite(p[0])&&std::isfinite(p[1])&&std::isfinite(p[2]);}
static Handle& checked(void*p){if(!p)throw std::runtime_error("null handle");Handle&h=*static_cast<Handle*>(p);if(!h.healthy)throw std::runtime_error("retired handle");return h;}
extern "C" {
const char* om_last_error(){return error.c_str();}
void* om_create(double resolution){try{if(!std::isfinite(resolution)||resolution<.01||resolution>1)throw std::runtime_error("invalid resolution");error.clear();return new Handle(resolution);}catch(const std::exception&e){error=e.what();return nullptr;}}
void om_destroy(void*p){delete static_cast<Handle*>(p);}
int om_defaults(void*p,double*out){try{auto&h=checked(p);if(!out)throw std::runtime_error("null output");out[0]=h.tree.getResolution();out[1]=h.tree.getProbHit();out[2]=h.tree.getProbMiss();out[3]=h.tree.getOccupancyThres();out[4]=h.tree.getClampingThresMin();out[5]=h.tree.getClampingThresMax();return 1;}catch(const std::exception&e){error=e.what();return 0;}}
int om_insert(void*p,uint64_t frame,const float*xyz,uint64_t count,const float*origin,ScanStats*out){
 try{auto&h=checked(p);if(frame!=h.next||frame>=8192||!finite3(origin)||!xyz||count==0||count>2000000||!out)throw std::runtime_error("invalid scan/owner");
  octomap::point3d sensor(origin[0],origin[1],origin[2]);octomap::OcTreeKey originKey;if(!h.tree.coordToKeyChecked(sensor,originKey))throw std::runtime_error("origin out of native bounds");
  octomap::KeySet allKeys;octomap::Pointcloud representatives;representatives.reserve(count);
  for(uint64_t i=0;i<count;++i){const float*q=xyz+3*i;if(!finite3(q))throw std::runtime_error("nonfinite endpoint");octomap::point3d endpoint(q[0],q[1],q[2]);octomap::OcTreeKey key;if(!h.tree.coordToKeyChecked(endpoint,key))throw std::runtime_error("endpoint out of native bounds");if(allKeys.insert(key).second)representatives.push_back(endpoint);}
  octomap::KeySet freeKeys,occupiedKeys;
  // Exact upstream computeUpdate; no discretize=true synthetic voxel-centre rays.
  h.tree.computeUpdate(representatives,sensor,freeKeys,occupiedKeys,-1.0);
  if(occupiedKeys.size()!=allKeys.size())throw std::runtime_error("occupied-set equivalence failed");
  for(const auto&k:allKeys)if(occupiedKeys.find(k)==occupiedKeys.end())throw std::runtime_error("lost occupied endpoint key");
  for(const auto&k:freeKeys)if(occupiedKeys.find(k)!=occupiedKeys.end())throw std::runtime_error("upstream occupied-wins contract violated");
  // Same upstream insertion order/updateNode operations, with a copied evidence counter.
  for(const auto&k:freeKeys){h.tree.updateNode(k,false,true);++h.evidence[packed(k)].frees;}
  for(const auto&k:occupiedKeys){h.tree.updateNode(k,true,true);++h.evidence[packed(k)].hits;}
  h.tree.updateInnerOccupancy();++h.next;uint64_t conflicts=0;for(const auto&e:h.evidence)if(e.second.hits&&e.second.frees)++conflicts;
  *out={frame,count,uint64_t(occupiedKeys.size()),uint64_t(representatives.size()),uint64_t(freeKeys.size()),uint64_t(h.tree.size()),conflicts};error.clear();return 1;
 }catch(const std::exception&e){if(p)static_cast<Handle*>(p)->healthy=false;error=e.what();return 0;}
}
int om_query(void*p,const float*xyz,uint64_t count,uint8_t*known,double*probability,float*logOdds,uint32_t*hits,uint32_t*frees){try{auto&h=checked(p);if(!xyz||count>5000000||!known||!probability||!logOdds||!hits||!frees)throw std::runtime_error("invalid query buffers");for(uint64_t i=0;i<count;++i){const float*q=xyz+3*i;if(!finite3(q))throw std::runtime_error("nonfinite query");octomap::point3d point(q[0],q[1],q[2]);octomap::OcTreeKey key;if(!h.tree.coordToKeyChecked(point,key))throw std::runtime_error("query out of bounds");auto*n=h.tree.search(key);known[i]=n?1:0;probability[i]=n?n->getOccupancy():NAN;logOdds[i]=n?n->getLogOdds():NAN;auto e=h.evidence.find(packed(key));hits[i]=e==h.evidence.end()?0:e->second.hits;frees[i]=e==h.evidence.end()?0:e->second.frees;}return 1;}catch(const std::exception&e){error=e.what();return 0;}}
uint64_t om_leaf_count(void*p){try{return checked(p).tree.getNumLeafNodes();}catch(const std::exception&e){error=e.what();return UINT64_MAX;}}
int om_export(void*p,uint64_t capacity,double*xyzSizeProbability,float*logOdds,uint32_t*hits,uint32_t*frees){try{auto&h=checked(p);if(capacity!=h.tree.getNumLeafNodes()||!xyzSizeProbability||!logOdds||!hits||!frees)throw std::runtime_error("export size mismatch");uint64_t i=0;for(auto it=h.tree.begin_leafs(),end=h.tree.end_leafs();it!=end;++it,++i){xyzSizeProbability[5*i]=it.getX();xyzSizeProbability[5*i+1]=it.getY();xyzSizeProbability[5*i+2]=it.getZ();xyzSizeProbability[5*i+3]=it.getSize();xyzSizeProbability[5*i+4]=it->getOccupancy();logOdds[i]=it->getLogOdds();auto e=h.evidence.find(packed(it.getKey()));hits[i]=e==h.evidence.end()?0:e->second.hits;frees[i]=e==h.evidence.end()?0:e->second.frees;}return i==capacity?1:0;}catch(const std::exception&e){error=e.what();return 0;}}
}
// Keep the threshold decision inside the upstream implementation.
extern "C" int om_query_occupied(void*p,const float*xyz,uint64_t count,uint8_t*known,uint8_t*occupied){try{auto&h=checked(p);if(!xyz||count>5000000||!known||!occupied)throw std::runtime_error("invalid occupancy buffers");for(uint64_t i=0;i<count;++i){const float*q=xyz+3*i;if(!finite3(q))throw std::runtime_error("nonfinite occupancy query");octomap::OcTreeKey key;if(!h.tree.coordToKeyChecked(octomap::point3d(q[0],q[1],q[2]),key))throw std::runtime_error("occupancy query out of bounds");auto*n=h.tree.search(key);known[i]=n?1:0;occupied[i]=n&&h.tree.isNodeOccupied(n)?1:0;}return 1;}catch(const std::exception&e){error=e.what();return 0;}}
