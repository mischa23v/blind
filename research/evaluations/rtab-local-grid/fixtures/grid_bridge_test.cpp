#include "BlindLocalGridBridge.hpp"
#include <cassert>
#include <iostream>
#include <vector>
#include <atomic>
#include <thread>
#include <chrono>
using namespace blind_grid;
int main() {
    double matrix[16];identity(matrix);CaptureRegistry registry;Capture c;
    assert(registry.record(1001,1,4,7,matrix));assert(registry.find(1001,4,7,c)&&c.uptime==1&&c.sequence==1);
    assert(!registry.find(1001,5,7,c));assert(!registry.find(1001,4,8,c));
    assert(!registry.record(1002,1,4,7,matrix));assert(!registry.record(INFINITY,2,4,7,matrix));
    registry.clear();assert(!registry.find(1001,4,7,c));
    for(int i=0;i<130;++i) assert(registry.record(2000+i,2+i,4,8,matrix));
    assert(!registry.find(2000,4,8,c));assert(registry.find(2129,4,8,c));
    assert(!registry.record(2129,999,4,8,matrix));assert(!registry.find(2129,4,8,c));
    PacketStorage s;
    const float xyzrgb[]={1,2,3,NAN, 4,5,6,NAN};
    assert(copyXYZRGB(xyzrgb,8,2,s.ground,s.packet.ground));assert(s.packet.ground.count==2&&s.ground[5]==6);
    assert(!copyXYZRGB(xyzrgb,7,2,s.ground,s.packet.ground));
    float bad[]={NAN,2,3,0};assert(!copyXYZRGB(bad,4,1,s.ground,s.packet.ground));
    std::vector<float> large((BLIND_GRID_MAX_CELLS+1)*4,0);
    assert(copyXYZRGB(large.data(),large.size(),BLIND_GRID_MAX_CELLS+1,s.ground,s.packet.ground));
    assert(s.packet.ground.count==BLIND_GRID_MAX_CELLS&&s.packet.ground.truncated==1&&s.packet.ground.originalCount==BLIND_GRID_MAX_CELLS+1);
    assert(copyXYZRGB(nullptr,0,0,s.empty,s.packet.empty));assert(!s.packet.empty.available);
    auto &p=s.packet;p.status=BLIND_GRID_AVAILABLE;p.generation=4;p.frameRevision=8;p.eventRevision=1;p.captureSequence=1;
    p.nodeID=2;p.mapID=0;p.capturedAt=3;p.upstreamStamp=2001;p.cellSize=.1;p.hasCameraOpticalPose=1;
    p.poseCount=1;s.poses[0].nodeID=2;identity(s.poses[0].columns);
    assert(validPacket(p));p.ground.count=BLIND_GRID_MAX_CELLS+1;assert(!validPacket(p));p.ground.count=BLIND_GRID_MAX_CELLS;
    p.mapCorrection[0]=NAN;assert(!validPacket(p));identity(p.mapCorrection);
    p.poseCount=2;s.poses[1]=s.poses[0];assert(!validPacket(p));p.poseCount=1;
    p.mapFromCameraOptical[0]=-1;assert(!validPacket(p));identity(p.mapFromCameraOptical);
    p.capturedAt=INFINITY;assert(!validPacket(p));
    CallbackSlot slot;int delivered=0;
    slot.setOwner(4,8);slot.set(&delivered,[](void *context,const BlindGridPacket*){++*static_cast<int*>(context);});
    p.capturedAt=3;slot.deliver(p);slot.deliver(p);assert(delivered==1);
    slot.setOwner(4,9);slot.deliver(p);assert(delivered==1);
    struct Barrier {std::atomic<bool> entered{false},release{false},done{false};} barrier;
    slot.set(&barrier,[](void *context,const BlindGridPacket*){
        auto &b=*static_cast<Barrier*>(context);b.entered=true;while(!b.release)std::this_thread::yield();b.done=true;
    });
    p.frameRevision=9;p.eventRevision=1;
    std::thread emit([&]{slot.deliver(p);});while(!barrier.entered)std::this_thread::yield();
    std::atomic<bool> unregisterStarted{false},unregistered{false};
    std::thread unregister([&]{unregisterStarted=true;slot.set(nullptr,nullptr);assert(barrier.done);unregistered=true;});
    while(!unregisterStarted)std::this_thread::yield();
    std::this_thread::sleep_for(std::chrono::milliseconds(2));assert(!unregistered);
    barrier.release=true;emit.join();unregister.join();assert(unregistered);
    std::cout<<"C ABI packet/copy/association checks passed (real bridge helper; no RTAB engine execution)\n";
}
