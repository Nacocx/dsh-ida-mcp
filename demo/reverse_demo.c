#include <stdio.h>
#include <string.h>

/* A tiny key checker used to exercise the IDA MCP plugin end to end. */

static int transform(const char *s) {
    int acc = 0x5a;
    for (int i = 0; s[i] != '\0'; i++) {
        acc = ((acc << 5) + acc) ^ (unsigned char)s[i];
        acc &= 0xffff;
    }
    return acc;
}

int verify(const char *input) {
    if (strlen(input) != 8) {
        return 0;
    }
    return transform(input) == 0x4f3a;
}

int main(int argc, char **argv) {
    char buf[64];

    (void)argc;
    (void)argv;
    printf("enter key: ");
    if (fgets(buf, sizeof(buf), stdin) == NULL) {
        return 1;
    }
    buf[strcspn(buf, "\r\n")] = '\0';
    if (verify(buf)) {
        puts("access granted: flag{demo_pseudocode_ok}");
    } else {
        puts("denied");
    }
    return 0;
}
