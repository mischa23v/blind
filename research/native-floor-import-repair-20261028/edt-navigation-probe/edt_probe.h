#ifndef BLIND_EDT_PROBE_H
#define BLIND_EDT_PROBE_H
#include "blind_detour.h"
#ifdef __cplusplus
extern "C" {
#endif
int bn_probe_association(void*,const float*,const float*,float*,int*);
/* Diagnostic only. expected_hash32 is exactly32 bytes; keep has count0/1 bytes.
   The synchronous build copies these values; callers retain no borrowed buffer.
   mode0 observes original erosion; mode1 clears additional spans only AFTER a
   complete captured-layout hash match. No physical support/clearance authority. */
int bn_edt_begin(int profile_index,int mode,const unsigned char* expected_hash32,
                 const unsigned char* keep,int count);
/* Call immediately after build, including failed builds, BEFORE any route query.
   A zero return means the handle MUST be destroyed/withheld, not used as legacy
   fallback. Available outputs are initialized even on invalid arguments. */
int bn_edt_receipt(unsigned char* actual_hash32,int* original_keep,int* candidate_keep,
                   int* applied,int* layout_match,int* invalid);
void bn_edt_reset(void);
#ifdef __cplusplus
}
#endif
#endif
