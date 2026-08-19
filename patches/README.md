# Patches

This directory is reserved for future local patches against upstream StickyTags, LLVM, compiler-rt, or gperftools.

The first repository version does not vendor the full upstream source tree and does not include a generated patch set. The current reproduction records the upstream source version in `manifests/source-versions.txt` and `Experiment/logs/stage3-source-versions.txt`.

If later work changes upstream source files, export the changes here as patch files instead of committing the entire upstream checkout.
