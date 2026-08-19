#define _GNU_SOURCE
#include <errno.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/auxv.h>
#include <sys/mman.h>
#include <sys/prctl.h>
#include <unistd.h>

#include <asm/hwcap.h>

#ifndef PROT_MTE
#define PROT_MTE 0x20
#endif

int main(void) {
    unsigned long hwcap2 = getauxval(AT_HWCAP2);
    long page_size = sysconf(_SC_PAGESIZE);

    printf("AT_HWCAP2=0x%lx\n", hwcap2);
    printf("HWCAP2_MTE=%s\n", (hwcap2 & HWCAP2_MTE) ? "yes" : "no");
    printf("page_size=%ld\n", page_size);

    void *mapping = mmap(NULL, (size_t)page_size,
                         PROT_READ | PROT_WRITE | PROT_MTE,
                         MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (mapping == MAP_FAILED) {
        fprintf(stderr, "mmap(PROT_MTE) failed: %s\n", strerror(errno));
        return 2;
    }
    printf("mmap_PROT_MTE=ok\n");

    unsigned long control = PR_TAGGED_ADDR_ENABLE |
                            PR_MTE_TCF_SYNC |
                            (0xfffeUL << PR_MTE_TAG_SHIFT);
    if (prctl(PR_SET_TAGGED_ADDR_CTRL, control, 0, 0, 0) != 0) {
        fprintf(stderr, "PR_SET_TAGGED_ADDR_CTRL failed: %s\n", strerror(errno));
        munmap(mapping, (size_t)page_size);
        return 3;
    }
    printf("PR_SET_TAGGED_ADDR_CTRL=ok\n");
    munmap(mapping, (size_t)page_size);

    return (hwcap2 & HWCAP2_MTE) ? 0 : 4;
}
