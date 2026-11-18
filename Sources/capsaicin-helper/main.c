#include "request.h"
#include <dispatch/dispatch.h>
#include <os/log.h>
#include <signal.h>
#include <stdlib.h>
#include <sysexits.h>
#include <time.h>
#include <unistd.h>

int cleanup_boot(void);

static void defer_sigterm(int signo) { (void)signo; }

static void cleanup_disconnected_peer(xpc_connection_t peer) {
    pid_t pid = xpc_connection_get_pid(peer);
    if (helper_set_sleep_disabled(false))
        os_log(OS_LOG_DEFAULT, "Helper disconnect cleanup succeeded: peer_pid=%{public}d", pid);
    else
        os_log_error(OS_LOG_DEFAULT, "Helper disconnect cleanup failed: peer_pid=%{public}d", pid);
}

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
    __block size_t cleanup_connections = 0;
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
      __block bool owns_cleanup = false;
      xpc_connection_set_event_handler(peer, ^(xpc_object_t request) {
        if (request == XPC_ERROR_CONNECTION_INVALID && owns_cleanup) {
            cleanup_disconnected_peer(peer);
            --cleanup_connections;
            owns_cleanup = false;
            last_request = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
        }
        if (xpc_get_type(request) == XPC_TYPE_ERROR)
            return;
        last_request = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
        enum helper_command command = helper_request_command(request);
        if (command == HELPER_COMMAND_ON && !owns_cleanup) {
            owns_cleanup = true;
            ++cleanup_connections;
        } else if (command == HELPER_COMMAND_OFF && owns_cleanup) {
            owns_cleanup = false;
            --cleanup_connections;
        }
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
      if (cleanup_connections == 0 && clock_gettime_nsec_np(CLOCK_UPTIME_RAW) - last_request >= 30 * NSEC_PER_SEC)
          exit(0);
    });

    dispatch_source_t termination = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, SIGTERM, 0, queue);
    if (!termination)
        return EX_OSERR;
    dispatch_source_set_event_handler(termination, ^{
      // XPC と同じキューで、処理中の要求が終わってから後片付けする。
      if (cleanup_connections != 0) {
          if (helper_set_sleep_disabled(false))
              os_log(OS_LOG_DEFAULT, "Helper SIGTERM cleanup succeeded");
          else
              os_log_error(OS_LOG_DEFAULT, "Helper SIGTERM cleanup failed");
      }
      exit(0);
    });
    dispatch_source_set_registration_handler(termination, ^{
      // 監視を始めてから要求を受け付ける。シグナルハンドラーでは何もせず、後片付けはキューに任せる。
      if (signal(SIGTERM, defer_sigterm) == SIG_ERR)
          exit(EX_OSERR);
      dispatch_activate(timer);
      xpc_connection_activate(listener);
    });
    dispatch_activate(termination);
    dispatch_main();
}
