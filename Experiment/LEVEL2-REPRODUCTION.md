# StickyTags Level 2 Reproduction

Date: 2026-08-19

This document records the second reproduction level completed on the local
Windows + WSL2 + QEMU AArch64 MTE environment. The level 2 work stays within
local defensive testing and does not add exploit payloads.

## Added Files

- `tests/stickytags-level2.c`: standalone AArch64 test program for level 2.
- `build-level2-aarch64.sh`: builds both protected and unprotected level 2
  binaries.
- `run-level2-guest.sh`: runs level 2 cases inside the AArch64 guest.
- `run-level2-in-vm.sh`: launches the guest-side runner over SSH and writes
  summary logs.
- `logs/stage8-level2-build.log`: build log.
- `logs/stage8-level2-results.txt`: raw level 2 result records.
- `logs/stage8-level2-summary.txt`: summarized level 2 result table.

## Binaries Built

- Protected binary: `/opt/stickytags/bin/stickytags-level2`
- Baseline binary: `/opt/stickytags/bin/unprotected-level2`

The protected binary was built with:

- modified StickyTags LLVM/Clang from `/home/brave/stickytags-lab/build/llvm-rel-gcc13`
- `--target=aarch64-linux-gnu`
- `-march=armv8.5-a+memtag`
- `-fsanitize=safe-stack`
- modified StickyTags gperftools/TCMalloc
- `libtcmalloc.so.4` deployed under `/opt/stickytags/lib`

Build verification from `stage8-level2-build.log`:

- `stickytags-level2` is an AArch64 PIE executable.
- `stickytags-level2` has `RUNPATH=/opt/stickytags/lib`.
- `stickytags-level2` depends on `libtcmalloc.so.4`.
- SafeStack symbol count is `1`.
- `unprotected-level2` TCMalloc dependency count is `0`.

## Tests Implemented

1. Tag-cycle test

   Checks whether 32 adjacent objects show a 16-tag deterministic cycle. This
   is tested for heap and stack objects at sizes 16, 32, 64, 128, and 256
   bytes.

2. Boundary-distance test

   Checks spatial protection across slots 1 through 16. This is tested for
   heap and stack objects at sizes 16, 32, 64, and 128 bytes. Slots 1 through
   15 are expected to fault. Slot 16 is expected not to fault because the tag
   cycle repeats after 16 slots.

3. Persistence test

   Checks whether reused heap and stack addresses keep a stable tag across
   allocate/free or repeated stack-frame reuse. This is tested for heap and
   stack objects at sizes 16, 32, 64, 128, and 256 bytes, with 1000 iterations
   per case.

4. MTE granularity test

   Checks 16-byte granularity on a 10-byte logical object. Accesses at indexes
   9, 10, and 15 are expected not to fault. Accesses at indexes 16 and 32 are
   expected to fault. This is tested for both heap and stack objects, 20 trials
   per index.

## Level 2 Results

Raw result records: `logs/stage8-level2-results.txt`

Summary: `logs/stage8-level2-summary.txt`

Summary numbers:

| suite | kind | cases | passed | pass rate |
|---|---|---:|---:|---:|
| boundary | heap | 320 | 320 | 100.0% |
| boundary | stack | 320 | 320 | 100.0% |
| cycle | heap | 5 | 5 | 100.0% |
| cycle | stack | 5 | 5 | 100.0% |
| granularity | heap | 100 | 100 | 100.0% |
| granularity | stack | 100 | 100 | 100.0% |
| persistence | heap | 5 | 5 | 100.0% |
| persistence | stack | 5 | 5 | 100.0% |

Additional metrics:

- Total `RESULT` records: 860
- Failed records: 0
- Objects checked by tag-cycle tests: 320
- Persistence iterations: 10000
- Persistence address reuses: 9990
- Persistence tag mismatches: 0
- Fault-checking cases: 840
- Expected MTE faults: 680
- Observed MTE faults: 680

## Reproduction Boundary

Level 2 is closer to the StickyTags paper than level 1 because it checks the
core mechanism beyond two representative overflows:

- deterministic 16-tag reuse cycle
- distance-sensitive spatial protection
- tag persistence on address reuse
- MTE 16-byte granularity behavior

It is still not a full paper reproduction. It does not reproduce the paper's
large benchmark tables, SPEC/real-application evaluation, or hardware
performance overhead numbers. The current environment uses QEMU TCG for
functional validation, so timing data should not be compared with the paper's
real Arm MTE hardware measurements.

## Re-run Commands

Run these inside the `StickyTagsLab` WSL distribution:

```bash
/mnt/f/Paper/StickyTags/Experiment/build-level2-aarch64.sh
/mnt/f/Paper/StickyTags/Experiment/start-mte-vm.sh
/mnt/f/Paper/StickyTags/Experiment/wait-for-mte-vm.sh
/mnt/f/Paper/StickyTags/Experiment/deploy-functional-tests.sh
/mnt/f/Paper/StickyTags/Experiment/run-level2-in-vm.sh 5 20 1000
```
