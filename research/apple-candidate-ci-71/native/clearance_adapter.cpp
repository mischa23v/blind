// Exact original adapter included; upstream and build config unchanged.
#include "blind_detour_exclusion.cpp"
extern "C" int bn_sample(void* handle, const float* pos, const float* ext, float maxr, float* out, float* distance) {
 if(!handle||!finite3(pos)||!finite3(ext)||!out||!distance||!std::isfinite(maxr)||maxr<=0)return 0;
 BNHandle* h=static_cast<BNHandle*>(handle);dtQueryFilter f;dtPolyRef ref=0;
 dtStatus s=h->query->findNearestPoly(pos,ext,&f,&ref,out);if(dtStatusFailed(s)||!ref)return 0;
 float hp[3],hn[3];s=h->query->findDistanceToWall(ref,out,maxr,&f,distance,hp,hn);
 return dtStatusSucceed(s)&&!dtStatusDetail(s,DT_OUT_OF_NODES);
}
extern "C" int bn_segment(void* handle,const float* a,const float* b) {
 if(!handle||!finite3(a)||!finite3(b))return 0;
 BNHandle* h=static_cast<BNHandle*>(handle);dtQueryFilter f;dtPolyRef ref=0;float q[3],ext[3]={.001f,.3f,.001f};
 dtStatus s=h->query->findNearestPoly(a,ext,&f,&ref,q);if(dtStatusFailed(s)||!ref)return 0;
 float t=0,hn[3];dtPolyRef path[4096];int n=0;s=h->query->raycast(ref,q,b,&f,&t,hn,path,&n,4096);
 if(dtStatusFailed(s)||dtStatusDetail(s,DT_BUFFER_TOO_SMALL)||dtStatusDetail(s,DT_OUT_OF_NODES)||t<1.f||n<1)return 0;
 float height=0;s=h->query->getPolyHeight(path[n-1],b,&height);
 return dtStatusSucceed(s)&&std::fabs(height-b[1])<=.05f;
}
