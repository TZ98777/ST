# StickyTags Core Mechanism Validation

Date: 2026-08-19

This document records the core mechanism validation completed on the local
Windows + WSL2 + QEMU AArch64 MTE environment. This validation work stays within
local defensive testing and does not add exploit payloads.

## Added Files

- `tests/stickytags-mechanism.c`: standalone AArch64 test program for core mechanism validation.
- `build-mechanism-tests-aarch64.sh`: builds both protected and unprotected mechanism-validation
  binaries.
- `run-mechanism-tests-guest.sh`: runs core mechanism cases inside the AArch64 guest.
- `run-mechanism-tests-in-vm.sh`: launches the guest-side runner over SSH and writes
  summary logs.
- `logs/mechanism-test-build.log`: build log.
- `logs/mechanism-test-results.txt`: raw core mechanism result records.
- `logs/mechanism-test-summary.txt`: summarized core mechanism result table.

## Binaries Built

- Protected binary: `/opt/stickytags/bin/stickytags-mechanism`
- Baseline binary: `/opt/stickytags/bin/unprotected-mechanism`

The protected binary was built with:

- modified StickyTags LLVM/Clang from `/home/brave/stickytags-lab/build/llvm-rel-gcc13`
- `--target=aarch64-linux-gnu`
- `-march=armv8.5-a+memtag`
- `-fsanitize=safe-stack`
- modified StickyTags gperftools/TCMalloc
- `libtcmalloc.so.4` deployed under `/opt/stickytags/lib`

Build verification from `mechanism-test-build.log`:

- `stickytags-mechanism` is an AArch64 PIE executable.
- `stickytags-mechanism` has `RUNPATH=/opt/stickytags/lib`.
- `stickytags-mechanism` depends on `libtcmalloc.so.4`.
- SafeStack symbol count is `1`.
- `unprotected-mechanism` TCMalloc dependency count is `0`.

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

## Core Mechanism Validation Results

Raw result records: `logs/mechanism-test-results.txt`

Summary: `logs/mechanism-test-summary.txt`

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

The core mechanism validation is closer to the StickyTags paper than the initial functional smoke test because it checks the
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
./Experiment/build-mechanism-tests-aarch64.sh
./Experiment/start-mte-vm.sh
./Experiment/wait-for-mte-vm.sh
./Experiment/deploy-functional-tests.sh
./Experiment/run-mechanism-tests-in-vm.sh 5 20 1000
```
