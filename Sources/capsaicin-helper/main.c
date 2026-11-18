#include "request.h"
#include <dispatch/dispatch.h>
#include <os/log.h>
#include <stdlib.h>
#include <sysexits.h>
#include <time.h>
#include <unistd.h>

int cleanup_boot(void);

int main(int argc, char *argv[]) {
    (void)argv;
    if (argc != 1 || geteuid() != 0)
        return EX_USAGE;
    // 後片付けに失敗しても、on と off は受け付ける。終了すると、抑止もヘルパーの削除もできなくなる。
    if (cleanup_boot() != 0)
        os_log_error(OS_LOG_DEFAULT, "Helper boot cleanup failed");
    dispatch_queue_t queue = dispatch_get_main_queue();
    xpc_connection_t listener =
        xpc_connection_create_mach_service(HELPER_SERVICE_NAME, queue, XPC_CONNECTION_MACH_SERVICE_LISTENER);
    if (!listener)
        return EX_OSERR;
    // listener と個々の接続の両方で、要求を読む前に署名を照合する。
    if (xpc_connection_set_peer_team_identity_requirement(listener, HELPER_APP_IDENTIFIER) != 0)
        return EX_NOPERM;
    __block uint64_t last_request = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
    xpc_connection_set_event_handler(listener, ^(xpc_object_t event) {
      if (xpc_get_type(event) != XPC_TYPE_CONNECTION)
          return;
      xpc_connection_t peer = (xpc_connection_t)event;
      if (xpc_connection_set_peer_team_identity_requirement(peer, HELPER_APP_IDENTIFIER) != 0) {
          xpc_connection_cancel(peer);
          return;
      }
      // pmset の終了待ちも同じキューで行い、期限切れの要求が後の要求を追い越さないようにする。
      xpc_connection_set_target_queue(peer, queue);
      xpc_connection_set_event_handler(peer, ^(xpc_object_t request) {
        if (xpc_get_type(request) == XPC_TYPE_ERROR)
            return;
        last_request = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
        bool success = helper_handle_request(request);
        if (xpc_get_type(request) != XPC_TYPE_DICTIONARY)
            return;
        xpc_object_t reply = xpc_dictionary_create_reply(request);
        if (!reply)
            return;
        xpc_dictionary_set_bool(reply, "success", success);
        xpc_connection_send_message(peer, reply);
        xpc_release(reply);
      });
      xpc_connection_activate(peer);
    });
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), NSEC_PER_SEC, 0);
    dispatch_source_set_event_handler(timer, ^{
      if (clock_gettime_nsec_np(CLOCK_UPTIME_RAW) - last_request >= 30 * NSEC_PER_SEC)
          exit(0);
    });
    dispatch_activate(timer);
    xpc_connection_activate(listener);
    dispatch_main();
}
