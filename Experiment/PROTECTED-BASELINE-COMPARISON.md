# StickyTags Protected/Baseline Comparison Validation

Date: 2026-08-19

The protected/baseline comparison extends the core mechanism tests with a protected-vs-baseline
comparison. This follows the paper's evaluation style: StickyTags is evaluated
against unprotected or alternative baseline configurations, and its claims are
about deterministic bounded spatial protection, persistent tags, size-class
regions, and practical overhead.

This validation step still avoids performance claims because the local setup uses QEMU
TCG rather than real Arm MTE hardware.

## Paper Alignment

The following parts are directly aligned with the paper:

- Protected-vs-baseline comparison.
- Heap and stack coverage.
- Size-class based allocation behavior.
- Deterministic tag cycling across slots.
- Spatial protection caused by tag mismatch.
- Persistent tag behavior across reused locations.
- 16-byte MTE granularity.

The following parts are local engineering extensions, not exact paper table
reproduction:

- Repeating the small synthetic tests hundreds of times.
- Recording `layout_available` for the unprotected baseline.
- Treating QEMU results as functional evidence only.

The following paper content is not reproduced in the protected/baseline comparison:

- SPEC CPU2006 or SPEC CPU2017 performance tables.
- Real Arm MTE hardware timing.
- Memory overhead measurements on Pixel/Samsung devices.
- x86 analog redzone performance.
- Side-channel tag leakage experiments.

## Added Files

- `run-protected-baseline-guest.sh`: guest-side protected/baseline runner.
- `run-protected-baseline-in-vm.sh`: host-side SSH runner and summarizer.
- `logs/protected-baseline-results.txt`: raw protected/baseline comparison result records.
- `logs/protected-baseline-summary.txt`: summarized protected/baseline comparison result table.

The protected/baseline comparison reuses the binaries built for core mechanism validation:

- `/opt/stickytags/bin/stickytags-mechanism`
- `/opt/stickytags/bin/unprotected-mechanism`

## Test Matrix

Protected and baseline variants both run:

- cycle tests: heap and stack, sizes 16, 32, 64, 128, 256
- persistence tests: heap and stack, sizes 16, 32, 64, 128, 256, with 1000
  iterations per case
- boundary tests: heap and stack, sizes 16, 32, 64, 128, slots 1 through 16,
  5 trials per slot
- granularity tests: heap and stack, indexes 9, 10, 15, 16, 32, 20 trials per
  index

## Results

Raw result records: `logs/protected-baseline-results.txt`

Summary: `logs/protected-baseline-summary.txt`

Overall checks:

- Total `RESULT` records: 1720
- Comparison failures: 0
- Protected expected MTE faults: 680
- Protected observed MTE faults: 680
- Baseline expected MTE faults: 0
- Baseline observed MTE faults: 0
- Unexpected non-MTE `SIGSEGV` records: 0
- Baseline layout-dependent cases skipped: 400

Summary table:

| variant | suite | kind | cases | comparison passed | skipped | failed | pass rate of executed cases |
|---|---|---|---:|---:|---:|---:|---:|
| protected | boundary | heap | 320 | 320 | 0 | 0 | 100.0% |
| protected | boundary | stack | 320 | 320 | 0 | 0 | 100.0% |
| protected | cycle | heap | 5 | 5 | 0 | 0 | 100.0% |
| protected | cycle | stack | 5 | 5 | 0 | 0 | 100.0% |
| protected | granularity | heap | 100 | 100 | 0 | 0 | 100.0% |
| protected | granularity | stack | 100 | 100 | 0 | 0 | 100.0% |
| protected | persistence | heap | 5 | 5 | 0 | 0 | 100.0% |
| protected | persistence | stack | 5 | 5 | 0 | 0 | 100.0% |
| baseline | boundary | heap | 320 | 0 | 320 | 0 | N/A |
| baseline | boundary | stack | 320 | 320 | 0 | 0 | 100.0% |
| baseline | cycle | heap | 5 | 5 | 0 | 0 | 100.0% |
| baseline | cycle | stack | 5 | 5 | 0 | 0 | 100.0% |
| baseline | granularity | heap | 100 | 60 | 40 | 0 | 100.0% |
| baseline | granularity | stack | 100 | 60 | 40 | 0 | 100.0% |
| baseline | persistence | heap | 5 | 5 | 0 | 0 | 100.0% |
| baseline | persistence | stack | 5 | 5 | 0 | 0 | 100.0% |

Important baseline interpretation:

- The baseline produced `0` MTE faults, as expected.
- The baseline had `400` `layout_available=0` records because it does not use
  StickyTags size-class regions. These are classified as `SKIP`, excluded from
  the executed-case pass rate, and are not presented as successful tests.
- Every observed fault retains its `si_code` and fault kind. Non-MTE
  segmentation faults fail the comparison rather than being counted as MTE
  faults.
- The baseline had `0` cycle mechanism passes, while the protected variant had
  `10`. This shows the 16-tag deterministic cycle is coming from StickyTags,
  not from normal AArch64 code.
- In the table, `comparison passed` means that the observed result matched the
  expectation for that variant. For example, baseline cycle rows count as
  comparison passes precisely because the StickyTags cycle was absent; they
  are not baseline mechanism passes.

## Conclusion

The protected/baseline comparison strengthens the reproduction beyond core mechanism validation by adding a full baseline
comparison over the same local mechanism tests. The result supports this
limited claim:

The local protected StickyTags build shows deterministic tag-cycle behavior and
MTE fault detection for the tested bounded spatial accesses, while the
unprotected baseline does not produce MTE faults or StickyTags tag-cycle
behavior.

It does not support full-paper performance claims, because those require real
hardware or the paper's benchmark setup.

## Re-run Commands

Run these inside the `StickyTagsLab` WSL distribution:

```bash
./Experiment/build-mechanism-tests-aarch64.sh
./Experiment/start-mte-vm.sh
./Experiment/wait-for-mte-vm.sh
./Experiment/deploy-functional-tests.sh
./Experiment/run-protected-baseline-in-vm.sh 5 20 1000
```
