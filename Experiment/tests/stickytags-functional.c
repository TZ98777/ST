#include <stdint.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/prctl.h>
#include <unistd.h>

#ifndef PR_SET_TAGGED_ADDR_CTRL
#define PR_SET_TAGGED_ADDR_CTRL 55
#endif
#ifndef PR_TAGGED_ADDR_ENABLE
#define PR_TAGGED_ADDR_ENABLE (1UL << 0)
#endif
#ifndef PR_MTE_TCF_ASYNC
#define PR_MTE_TCF_ASYNC (1UL << 2)
#endif
#ifndef PR_MTE_TAG_SHIFT
#define PR_MTE_TAG_SHIFT 3
#endif

#define ADDRESS_MASK 0x00ffffffffffffffULL

static unsigned pointer_tag(const void *pointer) {
    return (unsigned)(((uintptr_t)pointer >> 56) & 0x0f);
}

static uintptr_t raw_address(const void *pointer) {
    return ((uintptr_t)pointer) & ADDRESS_MASK;
}

static void segv_handler(int signal_number, siginfo_t *info, void *context) {
    (void)context;
    const char *kind = "other SIGSEGV";
#ifdef SEGV_MTEAERR
    if (info->si_code == SEGV_MTEAERR) {
        kind = "SEGV_MTEAERR (asynchronous MTE tag check fault)";
    }
#endif
#ifdef SEGV_MTESERR
    if (info->si_code == SEGV_MTESERR) {
        kind = "SEGV_MTESERR (synchronous MTE tag check fault)";
    }
#endif
    char message[256];
    int length = snprintf(message, sizeof(message),
                          "caught SIGSEGV: si_code=%d kind=%s si_addr=%p\n",
                          info->si_code, kind, info->si_addr);
    if (length > 0) {
        write(STDERR_FILENO, message, (size_t)length);
    }
    _exit(128 + signal_number);
}

static void install_segv_handler(void) {
    struct sigaction action;
    memset(&action, 0, sizeof(action));
    action.sa_sigaction = segv_handler;
    action.sa_flags = SA_SIGINFO;
    sigemptyset(&action.sa_mask);
    if (sigaction(SIGSEGV, &action, NULL) != 0) {
        perror("sigaction");
        exit(2);
    }
}

static void configure_mte_fault_mode(void) {
    unsigned long control = PR_TAGGED_ADDR_ENABLE | PR_MTE_TCF_ASYNC |
                            (0xffffUL << PR_MTE_TAG_SHIFT);
    if (prctl(PR_SET_TAGGED_ADDR_CTRL, control, 0, 0, 0) != 0) {
        perror("prctl(PR_SET_TAGGED_ADDR_CTRL)");
        exit(2);
    }
}

__attribute__((noinline)) static int heap_test(int overflow) {
    volatile unsigned char *first = malloc(32);
    volatile unsigned char *second = malloc(32);
    if (first == NULL || second == NULL) {
        perror("malloc");
        return 2;
    }

    printf("heap first=%p tag=%u second=%p tag=%u\n",
           (const void *)first, pointer_tag((const void *)first),
           (const void *)second, pointer_tag((const void *)second));
    first[0] = 0x11;
    first[31] = 0x22;

    if (overflow) {
        puts("about to write first[32] (one byte beyond the 32-byte object)");
        first[32] = 0x33;
        puts("heap out-of-bounds write returned; waiting for async MTE fault");
        for (volatile unsigned long i = 0; i < 10000000UL; ++i) {
        }
        sleep(1);
    }

    free((void *)second);
    free((void *)first);
    return 0;
}

__attribute__((noinline)) static int stack_test(size_t index) {
    volatile unsigned char first[32];
    volatile unsigned char second[32];

    memset((void *)first, 0, sizeof(first));
    memset((void *)second, 0, sizeof(second));
    printf("stack first=%p tag=%u second=%p tag=%u index=%zu\n",
           (const void *)first, pointer_tag((const void *)first),
           (const void *)second, pointer_tag((const void *)second), index);
    first[0] = 0x44;
    if (index < sizeof(first)) {
        first[index] = 0x55;
    } else {
        uintptr_t first_raw = raw_address((const void *)first);
        uintptr_t second_raw = raw_address((const void *)second);
        volatile unsigned char *lower = first_raw < second_raw ? first : second;
        uintptr_t lower_raw = first_raw < second_raw ? first_raw : second_raw;
        uintptr_t upper_raw = first_raw < second_raw ? second_raw : first_raw;
        if (upper_raw - lower_raw != sizeof(first)) {
            fprintf(stderr,
                    "stack layout unavailable: raw distance=%zu, expected=%zu\n",
                    (size_t)(upper_raw - lower_raw), sizeof(first));
            return 3;
        }
        puts("about to write one byte past the lower-address stack object");
        lower[index] = 0x55;
        puts("stack out-of-bounds write returned; waiting for async MTE fault");
        for (volatile unsigned long i = 0; i < 10000000UL; ++i) {
        }
        sleep(1);
    }
    return 0;
}

int main(int argc, char **argv) {
    setvbuf(stdout, NULL, _IONBF, 0);
    setvbuf(stderr, NULL, _IONBF, 0);
    install_segv_handler();
    configure_mte_fault_mode();

    if (argc != 2) {
        fprintf(stderr, "usage: %s normal|heap-oob|stack-oob\n", argv[0]);
        return 64;
    }
    if (strcmp(argv[1], "normal") == 0) {
        int heap_result = heap_test(0);
        int stack_result = stack_test(31);
        puts("normal accesses completed");
        return heap_result != 0 ? heap_result : stack_result;
    }
    if (strcmp(argv[1], "heap-oob") == 0) {
        return heap_test(1);
    }
    if (strcmp(argv[1], "stack-oob") == 0) {
        return stack_test(32);
    }

    fprintf(stderr, "unknown mode: %s\n", argv[1]);
    return 64;
}
