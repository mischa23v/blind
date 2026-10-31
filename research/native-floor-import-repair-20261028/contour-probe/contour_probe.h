#ifndef BLIND_CONTOUR_PROBE_H
#define BLIND_CONTOUR_PROBE_H
#include "blind_detour.h"
#ifdef __cplusplus
extern "C" {
#endif
#define DECLARE_CONTOUR_PROBE(prefix) \
void* prefix##_build_classified(const float*,int,const int*,int,const BNConfig*,const unsigned char*); \
void prefix##_destroy(void*); \
const char* prefix##_last_error(void); \
int prefix##_path(void*,const float*,const float*,const float*,float*,int,float*,float*,unsigned int*,int*); \
int prefix##_association(void*,const float*,const float*,float*,int*);
DECLARE_CONTOUR_PROBE(bn_base)
DECLARE_CONTOUR_PROBE(bn_zero)
#undef DECLARE_CONTOUR_PROBE
#ifdef __cplusplus
}
#endif
#endif
