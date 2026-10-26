#include "BridgeFixture.h"
static blind_grid::CallbackSlot callbacks;static uint64_t generation=0;
extern "C" void setBlindGridCallbackNative(const void *,void *c,BlindGridCallback f) {callbacks.set(c,f);}
extern "C" void resetBlindGridNative(const void *,uint64_t g,bool) {generation=g;callbacks.setOwner(g,1);}
extern "C" uint32_t blindGridCapabilitiesNative(void) {return 0;}
extern "C" void destroyNativeApplication(const void *) {}
extern "C" void emitBlindGridFixture(uint32_t mode,uint64_t event) {
    blind_grid::PacketStorage storage;auto &p=storage.packet;
    p.status=BLIND_GRID_AVAILABLE;p.generation=generation;p.frameRevision=1;p.eventRevision=event;p.captureSequence=event;
    p.nodeID=1;p.mapID=0;p.capturedAt=double(event);p.upstreamStamp=1000+event;p.cellSize=.1;p.hasCameraOpticalPose=1;
    p.poseCount=1;storage.poses[0].nodeID=1;blind_grid::identity(storage.poses[0].columns);
    const float xyzrgb[]={1,2,3,0};blind_grid::copyXYZRGB(xyzrgb,4,1,storage.ground,p.ground);
    if(mode==1)p.ground.count=5000;
    callbacks.deliver(p);
    storage.ground[0]=999; // Must not mutate Swift-owned queued value.
}
