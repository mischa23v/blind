#ifndef BLIND_EARCUT_H
#define BLIND_EARCUT_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
/* Bounded CPU tessellation. Returns index count, -1 invalid input/output,
   -2 upstream/allocation failure. Indices address ORIGINAL input vertices.
   The caller MUST validate simple input ring and output area/boundary/winding;
   this adapter is not polygon repair or current floor/support evidence. */
int32_t bn_earcut_simple_ring(const double* xy, int32_t vertex_count,
                              int32_t* indices, int32_t capacity);
#ifdef __cplusplus
}
#endif
#endif
