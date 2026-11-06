#include "config.h"
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/resource.h>
#include <time.h>
#include <unistd.h>

static void record(FILE *log, const char *instance, const char *event) {
    if (fprintf(log, "%lld %d %s %s %s\n", (long long)time(NULL), getpid(), instance, PROBE_LABEL, event) < 0 ||
        fflush(log) != 0) {
        perror("probe: event output failed");
        exit(EXIT_FAILURE);
    }
}

static int finish(FILE *log) {
    if (fclose(log) != 0) {
        perror("probe: log close failed");
        return 1;
    }
    return 0;
}

int main(void) {
    const struct rlimit no_core = {0, 0};
    if (setrlimit(RLIMIT_CORE, &no_core) != 0) {
        perror("probe: setrlimit failed before start");
        return 1;
    }
    int directory = open(PROBE_WORKSPACE, O_RDONLY | O_DIRECTORY | O_NOFOLLOW);
    if (directory < 0) {
        perror("probe: workspace open failed before start");
        return 1;
    }
    int output = openat(directory, "events.log", O_WRONLY | O_APPEND | O_NOFOLLOW);
    FILE *log = output < 0 ? NULL : fdopen(output, "a");
    if (log == NULL) {
        perror("probe: log open failed before start");
        if (output >= 0)
            close(output);
        close(directory);
        return 1;
    }
    char instance[33];
    snprintf(instance, sizeof(instance), "%08x%08x%08x%08x", arc4random(), arc4random(), arc4random(), arc4random());
    char exit_request[48], crash_request[48];
    snprintf(exit_request, sizeof(exit_request), "exit-%s", instance);
    snprintf(crash_request, sizeof(crash_request), "crash-%s", instance);
    record(log, instance, "start");
    struct timespec start, now;
    clock_gettime(CLOCK_MONOTONIC, &start);
    for (;;) {
        if (unlinkat(directory, exit_request, 0) == 0) {
            record(log, instance, "normal-exit");
            break;
        }
        if (unlinkat(directory, crash_request, 0) == 0) {
            // 作業領域ごとに一度だけ。要求を消費してから自分だけを落とす。
            int used = openat(directory, "crash-used", O_CREAT | O_EXCL | O_WRONLY | O_NOFOLLOW, 0600);
            if (used >= 0) {
                close(used);
                record(log, instance, "self-crash");
                if (finish(log) != 0) {
                    close(directory);
                    return 1;
                }
                close(directory);
                raise(SIGABRT);
                return 1;
            }
            record(log, instance, "crash-refused");
        }
        clock_gettime(CLOCK_MONOTONIC, &now);
        if (now.tv_sec - start.tv_sec >= 900) {
            record(log, instance, "timeout");
            break;
        }
        sleep(1);
    }
    if (finish(log) != 0) {
        close(directory);
        return 1;
    }
    close(directory);
    return 0;
}
