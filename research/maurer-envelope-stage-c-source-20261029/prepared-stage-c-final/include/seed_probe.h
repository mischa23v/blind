#ifndef BLIND_SEED_PROBE_H
#define BLIND_SEED_PROBE_H
#include "blind_detour.h"
#ifdef __cplusplus
extern "C" {
#endif
int bn_probe_association(void*,const float*,const float*,float*,int*);
/* Scratch diagnostic observation only. Expected bits are NEVER applied.
   expect_veto selects which observation must exist, not geometry behavior. */
int bn_seed_probe_begin(int profile_index,int expect_veto,const unsigned char* expected_hash32,
                        const unsigned char* expected_keep,int count);
int bn_seed_probe_receipt(unsigned char* actual_hash32,int* original_keep,int* expected_keep,
    int* observed_veto_keep,int* layout_match,int* veto_observed,int* veto_match,int* invalid);
void bn_seed_probe_reset(void);
#ifdef __cplusplus
}
#endif
#endif
