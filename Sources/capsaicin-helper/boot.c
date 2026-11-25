#include "request.h"
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/sysctl.h>
#include <unistd.h>
#include <uuid/uuid.h>

static bool private_root_file(int descriptor, bool directory) {
    struct stat info;
    return fstat(descriptor, &info) == 0 && info.st_uid == 0 && !(info.st_mode & 0077) &&
           (directory ? S_ISDIR(info.st_mode) : S_ISREG(info.st_mode) && info.st_nlink == 1);
}

static int update_record(int directory, const char *boot) {
    char temporary[64];
    snprintf(temporary, sizeof(temporary), ".boot-session-%u", arc4random());
    int file = openat(directory, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0600);
    if (file < 0)
        return -1;
    size_t length = strlen(boot);
    int result = -1;
    if (write(file, boot, length) == (ssize_t)length && fsync(file) == 0 &&
        renameat(directory, temporary, directory, "boot-session-uuid") == 0 && fsync(directory) == 0)
        result = 0;
    close(file);
    unlinkat(directory, temporary, 0);
    return result;
}

int cleanup_boot(void) {
    char boot[37] = {0};
    size_t length = sizeof(boot);
    uuid_t parsed;
    if (sysctlbyname("kern.bootsessionuuid", boot, &length, NULL, 0) != 0 || boot[36] != '\0' ||
        uuid_parse(boot, parsed) != 0)
        return -1;
    int parent = open("/Library/Application Support", O_RDONLY | O_DIRECTORY | O_NOFOLLOW);
    if (parent < 0)
        return -1;
    struct stat info;
    if (fstat(parent, &info) != 0 || info.st_uid != 0 || (info.st_mode & 0022) ||
        (mkdirat(parent, HELPER_APP_IDENTIFIER, 0700) != 0 && errno != EEXIST)) {
        close(parent);
        return -1;
    }
    int directory = openat(parent, HELPER_APP_IDENTIFIER, O_RDONLY | O_DIRECTORY | O_NOFOLLOW);
    close(parent);
    if (directory < 0)
        return -1;
    int result = -1;
    if (!private_root_file(directory, true)) {
        close(directory);
        return -1;
    }
    int file = openat(directory, "boot-session-uuid", O_RDONLY | O_NOFOLLOW | O_NONBLOCK);
    if (file < 0 && errno == ENOENT) {
        result = update_record(directory, boot);
    } else {
        char previous[38] = {0};
        ssize_t count = -1;
        if (file >= 0) {
            count = private_root_file(file, false) ? read(file, previous, sizeof(previous) - 1) : -1;
            close(file);
        }
        // 読めない記録は前の起動のものと区別できないので、別の起動の記録として扱い、戻してから置き換える。
        // 「初回」とみなすと、記録が壊れている間は二度と後片付けをしなくなる。
        if (count == 36 && uuid_parse(previous, parsed) == 0 && strcmp(previous, boot) == 0)
            result = 0;
        else if (helper_set_sleep_disabled(false))
            result = update_record(directory, boot);
    }
    close(directory);
    return result;
}
