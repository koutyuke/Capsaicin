#include "request.h"
#include <errno.h>
#include <spawn.h>
#include <string.h>
#include <sys/wait.h>

bool helper_set_sleep_disabled(bool disabled) {
    char *arguments[] = {"/usr/bin/pmset", "-a", "disablesleep", disabled ? "1" : "0", NULL};
    char *environment[] = {NULL};
    pid_t pid;
    if (posix_spawn(&pid, "/usr/bin/pmset", NULL, NULL, arguments, environment) != 0)
        return false;
    int status;
    pid_t result;
    do {
        result = waitpid(pid, &status, 0);
    } while (result == -1 && errno == EINTR);
    return result == pid && WIFEXITED(status) && WEXITSTATUS(status) == 0;
}

enum helper_command helper_request_command(xpc_object_t request) {
    if (xpc_get_type(request) != XPC_TYPE_DICTIONARY || xpc_dictionary_get_count(request) != 1)
        return HELPER_COMMAND_INVALID;
    xpc_object_t value = xpc_dictionary_get_value(request, "command");
    if (!value || xpc_get_type(value) != XPC_TYPE_STRING)
        return HELPER_COMMAND_INVALID;
    const char *command = xpc_string_get_string_ptr(value);
    // XPC の文字列は長さも照合し、埋め込まれた NUL の後ろを見落とさない。
    size_t length = xpc_string_get_length(value);
    if (length == 2 && memcmp(command, "on", 2) == 0)
        return HELPER_COMMAND_ON;
    if (length == 3 && memcmp(command, "off", 3) == 0)
        return HELPER_COMMAND_OFF;
    return HELPER_COMMAND_INVALID;
}

bool helper_handle_request(xpc_object_t request) {
    enum helper_command command = helper_request_command(request);
    return command != HELPER_COMMAND_INVALID && helper_set_sleep_disabled(command == HELPER_COMMAND_ON);
}
