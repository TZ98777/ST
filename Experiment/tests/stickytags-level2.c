#include <signal.h>
#include <stdint.h>
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

#define MAX_OBJECTS 64
#define TOP_BYTE_MASK 0xff00000000000000ULL
#define ADDRESS_MASK 0x00ffffffffffffffULL

struct object_info {
    volatile unsigned char *ptr;
    uintptr_t tagged;
    uintptr_t raw;
    unsigned tag;
};

struct persistence_state {
    uintptr_t raw[MAX_OBJECTS];
    unsigned tag[MAX_OBJECTS];
    int count;
    int iterations;
    int reuses;
    int mismatches;
};

static volatile unsigned char byte_sink;

static unsigned pointer_tag(const void *pointer) {
    return (unsigned)(((uintptr_t)pointer >> 56) & 0x0f);
}

static uintptr_t raw_address(const void *pointer) {
    return ((uintptr_t)pointer) & ADDRESS_MASK;
}

static volatile unsigned char *retagged_pointer(const void *base,
                                                uintptr_t target_raw) {
    uintptr_t tagged = ((uintptr_t)base & TOP_BYTE_MASK) |
                       (target_raw & ADDRESS_MASK);
    return (volatile unsigned char *)tagged;
}

static void segv_handler(int signal_number, siginfo_t *info, void *context) {
    (void)context;
    const char *kind = "other";
#ifdef SEGV_MTEAERR
    if (info->si_code == SEGV_MTEAERR) {
        kind = "SEGV_MTEAERR";
    }
#endif
#ifdef SEGV_MTESERR
    if (info->si_code == SEGV_MTESERR) {
        kind = "SEGV_MTESERR";
    }
#endif
    char message[256];
    int length = snprintf(message, sizeof(message),
                          "MTE_FAULT,signal=%d,si_code=%d,kind=%s,si_addr=%p\n",
                          signal_number, info->si_code, kind, info->si_addr);
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
    (void)prctl(PR_SET_TAGGED_ADDR_CTRL, control, 0, 0, 0);
}

__attribute__((noinline)) static void escape_ptrs(volatile unsigned char **ptrs,
                                                   int count) {
    asm volatile("" : : "r"(ptrs), "r"(count) : "memory");
}

static void sort_objects(struct object_info *objects, int count) {
    for (int i = 1; i < count; ++i) {
        struct object_info current = objects[i];
        int j = i - 1;
        while (j >= 0 && objects[j].raw > current.raw) {
            objects[j + 1] = objects[j];
            --j;
        }
        objects[j + 1] = current;
    }
}

static void collect_objects(volatile unsigned char **ptrs, int count,
                            struct object_info *objects) {
    for (int i = 0; i < count; ++i) {
        objects[i].ptr = ptrs[i];
        objects[i].tagged = (uintptr_t)ptrs[i];
        objects[i].raw = raw_address((const void *)ptrs[i]);
        objects[i].tag = pointer_tag((const void *)ptrs[i]);
        ptrs[i][0] = (unsigned char)(0xa0U + (unsigned)i);
    }
    sort_objects(objects, count);
}

static int stride_ok(const struct object_info *objects, int start, int count,
                     size_t stride) {
    for (int i = 1; i < count; ++i) {
        if (objects[start + i].raw - objects[start + i - 1].raw != stride) {
            return 0;
        }
    }
    return 1;
}

static int find_contiguous_run(const struct object_info *objects, int count,
                               int needed, size_t stride) {
    for (int start = 0; start + needed <= count; ++start) {
        if (stride_ok(objects, start, needed, stride)) {
            return start;
        }
    }
    return -1;
}

static int report_cycle(const char *kind, size_t size,
                        struct object_info *objects, int count) {
    int seen[16] = {0};
    int unique_first16 = 0;
    int adjacent_diff = 0;
    int repeat16 = 0;
    int exact_stride = stride_ok(objects, 0, count, size);

    for (int i = 0; i < 16 && i < count; ++i) {
        if (!seen[objects[i].tag]) {
            seen[objects[i].tag] = 1;
            ++unique_first16;
        }
    }
    for (int i = 1; i < count; ++i) {
        if (objects[i].tag != objects[i - 1].tag) {
            ++adjacent_diff;
        }
    }
    for (int i = 0; i < 16 && i + 16 < count; ++i) {
        if (objects[i].tag == objects[i + 16].tag) {
            ++repeat16;
        }
    }

    int pass = count >= 32 && unique_first16 == 16 &&
               adjacent_diff == count - 1 && repeat16 == 16 && exact_stride;
    printf("RESULT,suite=cycle,kind=%s,size=%zu,objects=%d,"
           "unique_first16=%d,adjacent_diff=%d,repeat16=%d,stride_ok=%d,pass=%d\n",
           kind, size, count, unique_first16, adjacent_diff, repeat16,
           exact_stride, pass);
    return pass ? 0 : 1;
}

static int heap_cycle(size_t size) {
    volatile unsigned char *ptrs[32];
    struct object_info objects[32];
    for (int i = 0; i < 32; ++i) {
        ptrs[i] = malloc(size);
        if (ptrs[i] == NULL) {
            perror("malloc");
            return 2;
        }
    }
    collect_objects(ptrs, 32, objects);
    int result = report_cycle("heap", size, objects, 32);
    for (int i = 0; i < 32; ++i) {
        free((void *)ptrs[i]);
    }
    return result;
}

static int run_boundary_case(const char *kind, size_t size, int slot,
                             volatile unsigned char **ptrs, int count) {
    struct object_info objects[MAX_OBJECTS];
    collect_objects(ptrs, count, objects);
    int start = find_contiguous_run(objects, count, slot + 1, size);
    if (start < 0) {
        printf("RESULT,suite=boundary,kind=%s,size=%zu,slot=%d,"
               "layout=not_contiguous,pass=0\n",
               kind, size, slot);
        return 3;
    }

    volatile unsigned char *attack =
        retagged_pointer((const void *)objects[start].ptr,
                         objects[start + slot].raw);
    int expected_fault = objects[start].tag != objects[start + slot].tag;
    printf("CASE_SETUP,suite=boundary,kind=%s,size=%zu,slot=%d,"
           "base_tag=%u,target_tag=%u,expected_fault=%d\n",
           kind, size, slot, objects[start].tag, objects[start + slot].tag,
           expected_fault);
    attack[0] = 0x5a;
    for (volatile unsigned long i = 0; i < 1000000UL; ++i) {
    }
    usleep(100000);
    return expected_fault ? 7 : 0;
}

static int heap_boundary(size_t size, int slot) {
    volatile unsigned char *ptrs[MAX_OBJECTS];
    for (int i = 0; i < MAX_OBJECTS; ++i) {
        ptrs[i] = malloc(size);
        if (ptrs[i] == NULL) {
            perror("malloc");
            return 2;
        }
    }
    int result = run_boundary_case("heap", size, slot, ptrs, MAX_OBJECTS);
    for (int i = 0; i < MAX_OBJECTS; ++i) {
        free((void *)ptrs[i]);
    }
    return result;
}

static void persistence_record(struct persistence_state *state,
                               volatile unsigned char *ptr) {
    uintptr_t raw = raw_address((const void *)ptr);
    unsigned tag = pointer_tag((const void *)ptr);
    ++state->iterations;
    for (int i = 0; i < state->count; ++i) {
        if (state->raw[i] == raw) {
            ++state->reuses;
            if (state->tag[i] != tag) {
                ++state->mismatches;
            }
            return;
        }
    }
    if (state->count < MAX_OBJECTS) {
        state->raw[state->count] = raw;
        state->tag[state->count] = tag;
        ++state->count;
    }
}

static int heap_persistence(size_t size, int iterations) {
    struct persistence_state state;
    memset(&state, 0, sizeof(state));
    for (int i = 0; i < iterations; ++i) {
        volatile unsigned char *ptr = malloc(size);
        if (ptr == NULL) {
            perror("malloc");
            return 2;
        }
        ptr[0] = (unsigned char)i;
        persistence_record(&state, ptr);
        free((void *)ptr);
    }
    int pass = state.mismatches == 0 && state.reuses > 0;
    printf("RESULT,suite=persistence,kind=heap,size=%zu,iterations=%d,"
           "unique_addresses=%d,reuses=%d,mismatches=%d,pass=%d\n",
           size, state.iterations, state.count, state.reuses,
           state.mismatches, pass);
    return pass ? 0 : 1;
}

static int run_granularity_case(const char *kind, int index,
                                volatile unsigned char **ptrs, int count) {
    struct object_info objects[MAX_OBJECTS];
    collect_objects(ptrs, count, objects);
    int target_slot = index / 16;
    int start = find_contiguous_run(objects, count, target_slot + 1, 16);
    if (start < 0) {
        printf("RESULT,suite=granularity,kind=%s,size=10,index=%d,"
               "layout=not_contiguous,pass=0\n",
               kind, index);
        return 3;
    }

    uintptr_t target_raw = objects[start].raw + (uintptr_t)index;
    volatile unsigned char *attack =
        retagged_pointer((const void *)objects[start].ptr, target_raw);
    unsigned target_tag = objects[start + target_slot].tag;
    int expected_fault = objects[start].tag != target_tag;
    printf("CASE_SETUP,suite=granularity,kind=%s,size=10,index=%d,"
           "base_tag=%u,target_tag=%u,expected_fault=%d\n",
           kind, index, objects[start].tag, target_tag, expected_fault);
    byte_sink = attack[0];
    attack[0] = (unsigned char)(byte_sink + 1U);
    for (volatile unsigned long i = 0; i < 1000000UL; ++i) {
    }
    usleep(100000);
    return expected_fault ? 7 : 0;
}

static int heap_granularity(int index) {
    volatile unsigned char *ptrs[8];
    for (int i = 0; i < 8; ++i) {
        ptrs[i] = malloc(10);
        if (ptrs[i] == NULL) {
            perror("malloc");
            return 2;
        }
    }
    int result = run_granularity_case("heap", index, ptrs, 8);
    for (int i = 0; i < 8; ++i) {
        free((void *)ptrs[i]);
    }
    return result;
}

#define DECL_STACK_32(SZ)                                                     \
    volatile unsigned char a00[SZ], a01[SZ], a02[SZ], a03[SZ];                \
    volatile unsigned char a04[SZ], a05[SZ], a06[SZ], a07[SZ];                \
    volatile unsigned char a08[SZ], a09[SZ], a10[SZ], a11[SZ];                \
    volatile unsigned char a12[SZ], a13[SZ], a14[SZ], a15[SZ];                \
    volatile unsigned char a16[SZ], a17[SZ], a18[SZ], a19[SZ];                \
    volatile unsigned char a20[SZ], a21[SZ], a22[SZ], a23[SZ];                \
    volatile unsigned char a24[SZ], a25[SZ], a26[SZ], a27[SZ];                \
    volatile unsigned char a28[SZ], a29[SZ], a30[SZ], a31[SZ];                \
    volatile unsigned char *ptrs[32] = {                                      \
        a00, a01, a02, a03, a04, a05, a06, a07,                               \
        a08, a09, a10, a11, a12, a13, a14, a15,                               \
        a16, a17, a18, a19, a20, a21, a22, a23,                               \
        a24, a25, a26, a27, a28, a29, a30, a31                                \
    };                                                                        \
    escape_ptrs(ptrs, 32)

#define DEFINE_STACK_CYCLE(SZ)                                                \
    __attribute__((noinline)) static int stack_cycle_##SZ(void) {             \
        DECL_STACK_32(SZ);                                                    \
        struct object_info objects[32];                                       \
        collect_objects(ptrs, 32, objects);                                   \
        return report_cycle("stack", SZ, objects, 32);                       \
    }

#define DEFINE_STACK_BOUNDARY(SZ)                                             \
    __attribute__((noinline)) static int stack_boundary_##SZ(int slot) {       \
        DECL_STACK_32(SZ);                                                    \
        return run_boundary_case("stack", SZ, slot, ptrs, 32);               \
    }

#define DEFINE_STACK_PERSISTENCE(SZ)                                          \
    __attribute__((noinline)) static void stack_once_##SZ(                    \
        struct persistence_state *state) {                                     \
        volatile unsigned char object[SZ];                                    \
        volatile unsigned char *ptr = object;                                 \
        escape_ptrs(&ptr, 1);                                                  \
        ptr[0] = (unsigned char)state->iterations;                            \
        persistence_record(state, ptr);                                       \
    }

DEFINE_STACK_CYCLE(16)
DEFINE_STACK_CYCLE(32)
DEFINE_STACK_CYCLE(64)
DEFINE_STACK_CYCLE(128)
DEFINE_STACK_CYCLE(256)

DEFINE_STACK_BOUNDARY(16)
DEFINE_STACK_BOUNDARY(32)
DEFINE_STACK_BOUNDARY(64)
DEFINE_STACK_BOUNDARY(128)

DEFINE_STACK_PERSISTENCE(16)
DEFINE_STACK_PERSISTENCE(32)
DEFINE_STACK_PERSISTENCE(64)
DEFINE_STACK_PERSISTENCE(128)
DEFINE_STACK_PERSISTENCE(256)

__attribute__((noinline)) static int stack_granularity(int index) {
    volatile unsigned char a0[10], a1[10], a2[10], a3[10];
    volatile unsigned char a4[10], a5[10], a6[10], a7[10];
    volatile unsigned char *ptrs[8] = {a0, a1, a2, a3, a4, a5, a6, a7};
    escape_ptrs(ptrs, 8);
    return run_granularity_case("stack", index, ptrs, 8);
}

static int stack_cycle(size_t size) {
    switch (size) {
    case 16:
        return stack_cycle_16();
    case 32:
        return stack_cycle_32();
    case 64:
        return stack_cycle_64();
    case 128:
        return stack_cycle_128();
    case 256:
        return stack_cycle_256();
    default:
        fprintf(stderr, "unsupported stack size: %zu\n", size);
        return 64;
    }
}

static int stack_boundary(size_t size, int slot) {
    switch (size) {
    case 16:
        return stack_boundary_16(slot);
    case 32:
        return stack_boundary_32(slot);
    case 64:
        return stack_boundary_64(slot);
    case 128:
        return stack_boundary_128(slot);
    default:
        fprintf(stderr, "unsupported stack boundary size: %zu\n", size);
        return 64;
    }
}

static int stack_persistence(size_t size, int iterations) {
    struct persistence_state state;
    memset(&state, 0, sizeof(state));
    for (int i = 0; i < iterations; ++i) {
        switch (size) {
        case 16:
            stack_once_16(&state);
            break;
        case 32:
            stack_once_32(&state);
            break;
        case 64:
            stack_once_64(&state);
            break;
        case 128:
            stack_once_128(&state);
            break;
        case 256:
            stack_once_256(&state);
            break;
        default:
            fprintf(stderr, "unsupported stack persistence size: %zu\n", size);
            return 64;
        }
    }
    int pass = state.mismatches == 0 && state.reuses > 0;
    printf("RESULT,suite=persistence,kind=stack,size=%zu,iterations=%d,"
           "unique_addresses=%d,reuses=%d,mismatches=%d,pass=%d\n",
           size, state.iterations, state.count, state.reuses,
           state.mismatches, pass);
    return pass ? 0 : 1;
}

static size_t parse_size(const char *text) {
    char *end = NULL;
    unsigned long value = strtoul(text, &end, 10);
    if (end == NULL || *end != '\0' || value == 0) {
        fprintf(stderr, "invalid size: %s\n", text);
        exit(64);
    }
    return (size_t)value;
}

static int parse_int(const char *text, const char *name) {
    char *end = NULL;
    long value = strtol(text, &end, 10);
    if (end == NULL || *end != '\0') {
        fprintf(stderr, "invalid %s: %s\n", name, text);
        exit(64);
    }
    return (int)value;
}

int main(int argc, char **argv) {
    setvbuf(stdout, NULL, _IONBF, 0);
    setvbuf(stderr, NULL, _IONBF, 0);
    install_segv_handler();
    configure_mte_fault_mode();

    if (argc < 4) {
        fprintf(stderr,
                "usage: %s cycle heap|stack size\n"
                "       %s boundary heap|stack size slot\n"
                "       %s persistence heap|stack size iterations\n"
                "       %s granularity heap|stack index\n",
                argv[0], argv[0], argv[0], argv[0]);
        return 64;
    }

    const char *suite = argv[1];
    const char *kind = argv[2];
    if (strcmp(suite, "cycle") == 0 && argc == 4) {
        size_t size = parse_size(argv[3]);
        return strcmp(kind, "heap") == 0 ? heap_cycle(size) :
               strcmp(kind, "stack") == 0 ? stack_cycle(size) : 64;
    }
    if (strcmp(suite, "boundary") == 0 && argc == 5) {
        size_t size = parse_size(argv[3]);
        int slot = parse_int(argv[4], "slot");
        return strcmp(kind, "heap") == 0 ? heap_boundary(size, slot) :
               strcmp(kind, "stack") == 0 ? stack_boundary(size, slot) : 64;
    }
    if (strcmp(suite, "persistence") == 0 && argc == 5) {
        size_t size = parse_size(argv[3]);
        int iterations = parse_int(argv[4], "iterations");
        return strcmp(kind, "heap") == 0 ? heap_persistence(size, iterations) :
               strcmp(kind, "stack") == 0 ? stack_persistence(size, iterations)
                                            : 64;
    }
    if (strcmp(suite, "granularity") == 0 && argc == 4) {
        int index = parse_int(argv[3], "index");
        return strcmp(kind, "heap") == 0 ? heap_granularity(index) :
               strcmp(kind, "stack") == 0 ? stack_granularity(index) : 64;
    }

    fprintf(stderr, "invalid arguments\n");
    return 64;
}
