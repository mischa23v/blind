#include <stdbool.h>
#include "BlindLocalGridBridge.hpp"
#ifdef __cplusplus
extern "C" {
#endif
void setBlindGridCallbackNative(const void *,void *,BlindGridCallback);
void resetBlindGridNative(const void *,uint64_t,bool);
uint32_t blindGridCapabilitiesNative(void);
void destroyNativeApplication(const void *);
void emitBlindGridFixture(uint32_t mode,uint64_t event);
#ifdef __cplusplus
}
#endif
