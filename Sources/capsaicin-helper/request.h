#ifndef CAPSAICIN_HELPER_REQUEST_H
#define CAPSAICIN_HELPER_REQUEST_H
#include <stdbool.h>
#include <xpc/xpc.h>

bool helper_set_sleep_disabled(bool disabled);
bool helper_handle_request(xpc_object_t request);
#endif
