// Source-only additive adapter. Compile this translation unit INSTEAD OF the
// original adapter, never alongside it. The included source owns Handle/checks.
// Baseline adapter SHA256: 715b3e544dff913a82ec43f49c0255297af0c3a799397faceaa66ebe97f9dff7
#include "../coffee-octomap-build-source-20261029/octomap_adapter.cpp"
#include <initializer_list>
#include <limits>

enum RayStatus : uint32_t {
  RAY_UNRESOLVED = 0, RAY_HIT = 1, RAY_ORIGIN_UNKNOWN = 2,
  RAY_ORIGIN_OCCUPIED = 3, RAY_UNKNOWN_BEFORE_HIT = 4,
  RAY_RANGE_EXHAUSTED = 5, RAY_INVALID = 6, RAY_BOUNDS_REJECTED = 7,
  RAY_INTERSECTION_FAILED = 8
};

struct RayResult {
  uint32_t status, terminalKnown, terminalOccupied, hitScans, freeScans;
  double maxRange, centerProjectedRange, entryProjectedRange, probability, logOdds;
  double center[3], entry[3];
};

static RayResult empty_ray() {
  RayResult out{};
  const double nan = std::numeric_limits<double>::quiet_NaN();
  out.status = RAY_UNRESOLVED;
  out.maxRange = out.centerProjectedRange = out.entryProjectedRange = nan;
  out.probability = out.logOdds = nan;
  for (int i=0;i<3;++i) out.center[i] = out.entry[i] = nan;
  return out;
}

// Upstream coordToKeyChecked floors and casts to int BEFORE checking the key
// interval. Finite Float32 is therefore not sufficient admission. Reject in
// double precision, with two whole key cells of conservative interior margin,
// before any native coordinate-to-key conversion (including terminal queries).
static bool safe_native_coordinate(const Handle& h, double coordinate) {
  const double resolution=h.tree.getResolution();
  const unsigned depth=h.tree.getTreeDepth();
  if(!std::isfinite(coordinate) || !std::isfinite(resolution) ||
     resolution<.01 || resolution>1.0 || depth<2 || depth>30 ||
     depth>std::numeric_limits<octomap::key_type>::digits) return false;
  const double halfKeys=std::ldexp(1.0,int(depth)-1);
  const double scaled=(1.0/resolution)*coordinate;
  return std::isfinite(scaled) && scaled>-halfKeys+2.0 && scaled<halfKeys-2.0;
}

static bool safe_native_point(const Handle& h, const octomap::point3d& point) {
  for(int a=0;a<3;++a) if(!safe_native_coordinate(h,double(point[a]))) return false;
  return true;
}

static bool terminal(const Handle& h, const octomap::point3d& point, RayResult& out) {
  octomap::OcTreeKey key;
  if (!safe_native_point(h,point)) return false;
  if (!h.tree.coordToKeyChecked(point,key)) return false;
  auto* node = h.tree.search(key);
  out.terminalKnown = node ? 1 : 0;
  out.terminalOccupied = node && h.tree.isNodeOccupied(node) ? 1 : 0;
  if (node) { out.probability=node->getOccupancy(); out.logOdds=node->getLogOdds(); }
  auto it=h.evidence.find(packed(key));
  if (it!=h.evidence.end()) { out.hitScans=it->second.hits; out.freeScans=it->second.frees; }
  for(int i=0;i<3;++i) out.center[i]=point[i];
  return true;
}

extern "C" uint64_t om_ro_result_size() { return sizeof(RayResult); }

// Six uint64 values: scan count, tree nodes, leaves, evidence keys, hit votes,
// free votes. This is an adapter audit, not a confidence or safety score.
extern "C" int om_ro_state(void* handle, uint64_t* out) {
  try {
    const auto& h=checked(handle);
    if(!out) throw std::runtime_error("null read-only state output");
    uint64_t hits=0,frees=0;
    for(const auto& e:h.evidence) { hits+=e.second.hits; frees+=e.second.frees; }
    out[0]=h.next; out[1]=h.tree.size(); out[2]=h.tree.getNumLeafNodes();
    out[3]=h.evidence.size(); out[4]=hits; out[5]=frees;
    error.clear(); return 1;
  } catch(const std::exception& e) { error=e.what(); return 0; }
}

// Every ray uses official castRay(ignoreUnknown=false) and getRayIntersection.
// No insertion/update, replacement traversal, guessed Handle layout, or map load.
// Query-only input bounds: <=256 rays/batch and 0<maxRange<=8m. Reject, do not clamp.
extern "C" int om_ro_rays(void* handle, const float* origin,
                          const float* directions, const double* maxRanges,
                          uint64_t count, RayResult* output) {
  try {
    const auto& h=checked(handle);
    if(count>256 || !origin || (count && (!directions || !maxRanges || !output)))
      throw std::runtime_error("invalid read-only ray buffers/count");
    for(uint64_t i=0;i<count;++i) output[i]=empty_ray();
    for(uint64_t i=0;i<count;++i) {
      auto& out=output[i]; const float* d=directions+3*i;
      const double range=maxRanges[i]; out.maxRange=range;
      double norm2=0;
      for(int a=0;a<3;++a) norm2+=double(d[a])*double(d[a]);
      if(!finite3(origin) || !finite3(d) || !std::isfinite(range) || range<=0 || range>8.0 ||
         !std::isfinite(norm2) || norm2<=0) { out.status=RAY_INVALID; continue; }
      // Check the original coordinates and the entire query envelope as doubles
      // before forming any envelope float or calling native integer conversion.
      const double envelope=range+std::sqrt(3.0)*h.tree.getResolution();
      bool bounded=std::isfinite(envelope);
      for(int a=0;a<3;++a) {
        const double coordinate=double(origin[a]);
        if(!safe_native_coordinate(h,coordinate) ||
           !safe_native_coordinate(h,coordinate-envelope) ||
           !safe_native_coordinate(h,coordinate+envelope)) bounded=false;
      }
      if(!bounded) { out.status=RAY_BOUNDS_REJECTED; continue; }
      const octomap::point3d sensor(origin[0],origin[1],origin[2]);
      const octomap::point3d direction(d[0],d[1],d[2]);
      const auto normalized=direction.normalized();
      if(!std::isfinite(normalized[0]) || !std::isfinite(normalized[1]) ||
         !std::isfinite(normalized[2]) || normalized.norm()==0) { out.status=RAY_INVALID; continue; }
      octomap::OcTreeKey originKey;
      if(!h.tree.coordToKeyChecked(sensor,originKey)) { out.status=RAY_BOUNDS_REJECTED; continue; }
      auto* start=h.tree.search(originKey);
      if(!start || h.tree.isNodeOccupied(start)) {
        terminal(h,h.tree.keyToCoord(originKey),out);
        out.status=start ? RAY_ORIGIN_OCCUPIED : RAY_ORIGIN_UNKNOWN;
        continue;
      }
      octomap::point3d end(0,0,0); // defined even if an unexpected upstream error returns
      const bool hit=h.tree.castRay(sensor,direction,end,false,range);
      if(!terminal(h,end,out)) { out.status=RAY_UNRESOLVED; continue; }
      double nativeCenterNorm2=0,centerProjection=0;
      const double norm=std::sqrt(norm2);
      for(int a=0;a<3;++a) {
        const double delta=double(end[a])-double(sensor[a]);
        // Match upstream's float subtraction/product before double accumulation.
        nativeCenterNorm2+=(end[a]-sensor[a])*(end[a]-sensor[a]);
        centerProjection+=delta*double(d[a])/norm;
      }
      out.centerProjectedRange=centerProjection;
      if(!hit) {
        // This order mirrors upstream: max range is checked before node lookup.
        if(nativeCenterNorm2>range*range) out.status=RAY_RANGE_EXHAUSTED;
        else if(!out.terminalKnown) out.status=RAY_UNKNOWN_BEFORE_HIT;
        else out.status=RAY_UNRESOLVED;
        continue;
      }
      if(!out.terminalOccupied) { out.status=RAY_UNRESOLVED; continue; }
      octomap::point3d entry(0,0,0);
      if(!h.tree.getRayIntersection(sensor,direction,end,entry,0.0)) {
        out.status=RAY_INTERSECTION_FAILED; continue;
      }
      double entryProjection=0; bool finite=true;
      for(int a=0;a<3;++a) {
        finite=finite && std::isfinite(entry[a]);
        entryProjection+=(double(entry[a])-double(sensor[a]))*double(d[a])/norm;
      }
      if(!finite || !std::isfinite(entryProjection) || entryProjection<0) {
        out.status=RAY_INTERSECTION_FAILED; continue;
      }
      for(int a=0;a<3;++a) out.entry[a]=entry[a];
      out.entryProjectedRange=entryProjection; out.status=RAY_HIT;
    }
    error.clear(); return 1;
  } catch(const std::exception& e) { error=e.what(); return 0; }
}
