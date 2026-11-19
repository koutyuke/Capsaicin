#ifndef CAPSAICIN_HELPER_REQUEST_H
#define CAPSAICIN_HELPER_REQUEST_H
#include <stdbool.h>
#include <xpc/xpc.h>

enum helper_command {
    HELPER_COMMAND_INVALID,
    HELPER_COMMAND_ON,
    HELPER_COMMAND_OFF,
};

bool helper_set_sleep_disabled(bool disabled);
enum helper_command helper_request_command(xpc_object_t request);
bool helper_handle_request(xpc_object_t request);
#endif
