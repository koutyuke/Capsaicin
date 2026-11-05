#include "CapsaicinLEDShim.h"

// 公開ヘッダーにない宣言だけを閉じ込める。列挙値と ABI は Apple/WebKit の宣言に合わせる。
typedef CF_ENUM(int, IOHIDEventSystemClientType) {
    kIOHIDEventSystemClientTypeAdmin = 0,
    kIOHIDEventSystemClientTypeMonitor = 1,
    kIOHIDEventSystemClientTypePassive = 2,
    kIOHIDEventSystemClientTypeRateControlled = 3,
    kIOHIDEventSystemClientTypeSimple = 4,
};

extern IOHIDEventSystemClientRef _Nullable IOHIDEventSystemClientCreateWithType(CFAllocatorRef _Nullable allocator,
                                                                                IOHIDEventSystemClientType type,
                                                                                CFDictionaryRef _Nullable attributes)
    __attribute__((weak_import)) CF_RETURNS_RETAINED;

bool CapsaicinLEDClientSymbolAvailable(void) { return IOHIDEventSystemClientCreateWithType != NULL; }

IOHIDEventSystemClientRef _Nullable CapsaicinLEDCreatePassiveClient(void) {
    if (!CapsaicinLEDClientSymbolAvailable()) {
        return NULL;
    }
    return IOHIDEventSystemClientCreateWithType(kCFAllocatorDefault, kIOHIDEventSystemClientTypePassive, NULL);
}
