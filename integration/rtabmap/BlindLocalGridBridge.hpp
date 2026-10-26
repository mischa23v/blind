#ifndef BLIND_LOCAL_GRID_BRIDGE_HPP
#define BLIND_LOCAL_GRID_BRIDGE_HPP
#include <stdint.h>
#include <stddef.h>

// Bounded non-owning C ABI. Buffers live only for the synchronous callback.
// Geometry is node-local RTAB base-frame XYZ (metres), NOT current clearance.
enum { BLIND_GRID_SCHEMA = 1, BLIND_GRID_MAX_CELLS = 4096, BLIND_GRID_MAX_POSES = 64 };
enum { BLIND_GRID_AVAILABLE = 1, BLIND_GRID_UNAVAILABLE = 2, BLIND_GRID_INVALID = 3, BLIND_GRID_UNASSOCIATED = 4 };
typedef struct BlindGridCells {
    const float *xyz;
    uint32_t count;
    uint64_t originalCount;
    uint32_t available;
    uint32_t truncated;
} BlindGridCells;
typedef struct BlindGridPose { int32_t nodeID; double columns[16]; } BlindGridPose;
typedef struct BlindGridPacket {
    uint32_t schema, status;
    uint64_t generation, frameRevision, eventRevision, captureSequence;
    int32_t nodeID, mapID;
    double capturedAt, upstreamStamp, cellSize;
    double mapCorrection[16], cameraToARWorld[16], mapFromCameraOptical[16];
    uint32_t hasCameraOpticalPose;
    const BlindGridPose *poses;
    uint32_t poseCount, graphTruncated;
    BlindGridCells ground, obstacles, empty;
} BlindGridPacket;
typedef void (*BlindGridCallback)(void *, const BlindGridPacket *);

#ifdef __cplusplus
#include <algorithm>
#include <array>
#include <cmath>
#include <limits>
#include <mutex>
namespace blind_grid {
inline bool finiteMatrix(const double *c) {
    if (!c) return false;
    for (size_t i = 0; i < 16; ++i) if (!std::isfinite(c[i]) || std::abs(c[i]) > 1e6) return false;
    if (std::abs(c[3]) > 1e-6 || std::abs(c[7]) > 1e-6 || std::abs(c[11]) > 1e-6 || std::abs(c[15]-1) > 1e-6) return false;
    for (int a=0;a<3;++a) for (int b=a;b<3;++b) {
        double dot=0; for (int r=0;r<3;++r) dot+=c[a*4+r]*c[b*4+r];
        if (std::abs(dot-(a==b?1:0))>0.001) return false;
    }
    const double det=c[0]*(c[5]*c[10]-c[9]*c[6])-c[4]*(c[1]*c[10]-c[9]*c[2])+c[8]*(c[1]*c[6]-c[5]*c[2]);
    return std::abs(det-1)<0.001;
}
inline void identity(double *c) { std::fill(c,c+16,0); c[0]=c[5]=c[10]=c[15]=1; }
// Unregister is a draining barrier. Swift owns a separate weak-owner context
// until set(nullptr,nullptr) returns; callbacks never receive a raw Swift owner.
// A callback may copy/enqueue only; it must not re-enter this slot synchronously.
class CallbackSlot {
    std::mutex mutex_;
    BlindGridCallback callback_=nullptr;
    void * context_=nullptr;
    uint64_t generation_=0,frame_=0,lastEvent_=0;
public:
    void set(void *context,BlindGridCallback callback) {
        std::lock_guard<std::mutex> lock(mutex_);context_=context;callback_=callback;
    }
    void setOwner(uint64_t generation,uint64_t frame) {
        std::lock_guard<std::mutex> lock(mutex_);generation_=generation;frame_=frame;lastEvent_=0;
    }
    bool enabled() {std::lock_guard<std::mutex> lock(mutex_);return callback_!=nullptr;}
    void deliver(const BlindGridPacket &packet) {
        std::lock_guard<std::mutex> lock(mutex_);
        if(!callback_||packet.generation!=generation_||packet.frameRevision!=frame_||packet.eventRevision<=lastEvent_)return;
        lastEvent_=packet.eventRevision;callback_(context_,&packet);
    }
};
struct Capture {
    double epoch=0, uptime=0;
    uint64_t generation=0, frameRevision=0, sequence=0;
    std::array<double,16> cameraToARWorld{};
};
// Caller owns synchronization. Exact epoch keys are computed by the same camera
// offset+deviceStamp operation as SensorData, never guessed from callback time.
class CaptureRegistry {
    std::array<Capture,128> entries_{};
    size_t next_=0;
    double lastUptime_=-1;
    uint64_t sequence_=0;
public:
    void clear() { entries_={}; next_=0; lastUptime_=-1; sequence_=0; }
    bool record(double epoch,double uptime,uint64_t generation,uint64_t frameRevision,const double *camera) {
        if(!std::isfinite(epoch)||epoch<=0) return false;
        for(auto &e:entries_) if(e.epoch==epoch) { e=Capture{}; return false; }
        if(!std::isfinite(uptime)||uptime<0||uptime<=lastUptime_||!generation||!frameRevision||!finiteMatrix(camera)||sequence_==UINT64_MAX) return false;
        Capture c; c.epoch=epoch;c.uptime=uptime;c.generation=generation;c.frameRevision=frameRevision;c.sequence=++sequence_;
        std::copy(camera,camera+16,c.cameraToARWorld.begin()); entries_[next_]=c;next_=(next_+1)%entries_.size();lastUptime_=uptime;return true;
    }
    bool find(double epoch,uint64_t generation,uint64_t frameRevision,Capture &out) const {
        if(!std::isfinite(epoch)||epoch<=0) return false;
        for(const auto &e:entries_) if(e.epoch==epoch&&e.generation==generation&&e.frameRevision==frameRevision) {out=e;return true;}
        return false;
    }
};
struct PacketStorage {
    BlindGridPacket packet{};
    std::array<BlindGridPose,BLIND_GRID_MAX_POSES> poses{};
    std::array<float,BLIND_GRID_MAX_CELLS*3> ground{},obstacles{},empty{};
    PacketStorage() {
        packet.schema=BLIND_GRID_SCHEMA;packet.status=BLIND_GRID_UNAVAILABLE;packet.poses=poses.data();
        packet.ground.xyz=ground.data();packet.obstacles.xyz=obstacles.data();packet.empty.xyz=empty.data();
        identity(packet.mapCorrection);identity(packet.cameraToARWorld);identity(packet.mapFromCameraOptical);
    }
    PacketStorage(const PacketStorage&)=delete;
    PacketStorage& operator=(const PacketStorage&)=delete;
};
// Explicit configured producer: Grid/Sensor=1, Grid/3D=true -> PointXYZRGB.
// A packed RGB float may have NaN bits: validate XYZ only, never color.
inline bool copyXYZRGB(const float *source,size_t availableFloats,uint64_t originalCount,
                       std::array<float,BLIND_GRID_MAX_CELLS*3>& output,BlindGridCells &cells) {
    cells.count=0;cells.originalCount=originalCount;cells.available=0;cells.truncated=0;cells.xyz=output.data();
    if(!originalCount) return source==nullptr || availableFloats==0;
    if(!source||originalCount>SIZE_MAX/4||availableFloats<originalCount*4) return false;
    const uint32_t count=static_cast<uint32_t>(std::min<uint64_t>(originalCount,BLIND_GRID_MAX_CELLS));
    for(uint32_t i=0;i<count;++i) for(uint32_t j=0;j<3;++j) {
        const float v=source[size_t(i)*4+j];if(!std::isfinite(v)||std::abs(v)>1e6) return false;
        output[size_t(i)*3+j]=v;
    }
    cells.count=count;cells.available=1;cells.truncated=originalCount>count;return true;
}
inline bool validCells(const BlindGridCells &c) {
    if(c.count>BLIND_GRID_MAX_CELLS||c.originalCount<c.count||c.available>1||c.truncated>1) return false;
    if(c.truncated!=(c.originalCount>c.count)) return false;
    if(!c.available) return c.count==0&&c.originalCount==0;
    if(c.count&&!c.xyz) return false;
    for(size_t i=0;i<size_t(c.count)*3;++i) if(!std::isfinite(c.xyz[i])||std::abs(c.xyz[i])>1e6) return false;
    return true;
}
inline bool validPacket(const BlindGridPacket &p) {
    if(p.schema!=BLIND_GRID_SCHEMA||!p.generation||!p.frameRevision||!p.eventRevision||p.status<1||p.status>4||p.poseCount>BLIND_GRID_MAX_POSES||p.graphTruncated>1||p.hasCameraOpticalPose>1) return false;
    if(p.status!=BLIND_GRID_AVAILABLE) return true; // unavailable packets carry no usable geometry
    if(!p.captureSequence||p.nodeID<=0||p.mapID<0||!std::isfinite(p.capturedAt)||p.capturedAt<0||!std::isfinite(p.upstreamStamp)||p.upstreamStamp<=0||!std::isfinite(p.cellSize)||p.cellSize<0.01||p.cellSize>1) return false;
    if(!finiteMatrix(p.mapCorrection)||!finiteMatrix(p.cameraToARWorld)||!p.hasCameraOpticalPose||!finiteMatrix(p.mapFromCameraOptical)||!p.poseCount||!p.poses) return false;
    bool found=false;
    for(uint32_t i=0;i<p.poseCount;++i) {
        if(p.poses[i].nodeID<=0||!finiteMatrix(p.poses[i].columns)) return false;
        for(uint32_t j=0;j<i;++j) if(p.poses[i].nodeID==p.poses[j].nodeID) return false;
        found=found||p.poses[i].nodeID==p.nodeID;
    }
    return found&&validCells(p.ground)&&validCells(p.obstacles)&&validCells(p.empty);
}
}
#endif
#endif
