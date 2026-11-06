#include <string.h>
#include <sysexits.h>
#include <unistd.h>

int main(int argc, char *argv[]) {
    if (argc != 2) {
        return EX_USAGE;
    }

    char *value;
    if (strcmp(argv[1], "on") == 0) {
        value = "1";
    } else if (strcmp(argv[1], "off") == 0) {
        value = "0";
    } else {
        return EX_USAGE;
    }

    char *arguments[] = {"/usr/bin/pmset", "-a", "disablesleep", value, NULL};
    char *environment[] = {NULL};
    execve("/usr/bin/pmset", arguments, environment);
    return EX_OSERR;
}
