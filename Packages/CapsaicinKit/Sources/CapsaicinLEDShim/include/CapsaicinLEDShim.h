#ifndef CAPSAICIN_LED_SHIM_H
#define CAPSAICIN_LED_SHIM_H

#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/hidsystem/IOHIDEventSystemClient.h>
#include <stdbool.h>

bool CapsaicinLEDClientSymbolAvailable(void);
IOHIDEventSystemClientRef _Nullable CapsaicinLEDCreatePassiveClient(void) CF_RETURNS_RETAINED;

#endif
