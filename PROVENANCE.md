# Rewrite provenance

This record applies to the independently structured runtime and benchmark implementation on `feature/clean-room-rewrite`.

## Functional authorities

- `matrix2669/workspace/projects/ffmpeg-asr/README.md` at workspace commit `4102563425631edef07899ed1cc8fc95423e05f6`: clean-rewrite scope, prior-art inventory, required behavior, prohibited donor categories, and provenance discipline. License: repository governance material owned by matrix2669. Use: functional specification; no implementation copied.
- `README.md`, `DECISIONS.md`, `AGENT.md`, `BRANCHES.md`, and tests in `matrix2669/ffmpeg-asr`: public compatibility, accepted behavior, safety, branch, and validation contracts. Use: observable behavior and interface specification.
- Existing implementation baseline `matrix2669/ffmpeg-asr` commit `7829924588336f1de07f18d944472c429a32c5b1`, plus accepted adaptive-probing behavior at `ecc64244dae2c0e80761da6f16be92d95b91d29a`. Upstream ancestry remains unlicensed. Use: black-box old-versus-new validation and interface/behavior checks only; no source expression intentionally copied into the replacement runtime.
- Complete “Copyright and Code Overlap Review” project conversation, reviewed 2026-08-29. Use: licensing boundary, provenance requirements, and independent-rewrite intent; conversation claims about completed code were reverified against GitHub and were not accepted without repository evidence.

## Public technical references

| Source | License/status | Use | Expression copied |
|---|---|---|---|
| [FFmpeg project and manuals](https://ffmpeg.org/documentation.html) | FFmpeg project licensing | FFmpeg/FFprobe CLI behavior, filters, encoders, hardware-device initialization, MPEG-TS muxing | No |
| [FFmpeg QSV transcode example](https://github.com/FFmpeg/FFmpeg/blob/master/doc/examples/qsv_transcode.c) | FFmpeg repository license | QSV concepts and device/filter relationships | No |
| [Linux DRM sysfs ABI](https://www.kernel.org/doc/Documentation/ABI/testing/sysfs-class-drm) | Linux kernel documentation | Render-node and sysfs hardware identity | No |
| [Intel compute-runtime device table](https://github.com/intel/compute-runtime/blob/master/shared/source/dll/devices/devices_base.inl) | MIT | PCI `0xA7A0` identification as Intel Iris Xe Graphics | No |
| [Intel Arc A310 product material](https://www.intel.com/content/www/us/en/products/sku/227958/intel-arc-a310-graphics/overview.html) | Public vendor documentation | Discrete GPU identity/capability context | No |
| [Jellyfish test-media prior art](https://larmoire.org/jellyfish/) | Public test media; redistribution terms not relied upon | Historical benchmark comparison only; rewrite generates local bounded fixtures instead | No |

No GPL, copyleft, or unlicensed implementation was used as a code donor. Related implementations listed in the workspace sidecar were treated only as prior-art warnings and were not consulted for source expression during this implementation.

## Independent implementation choices

- Thin compatibility entry point with separate common, CLI, cache, hardware, probe, and policy modules.
- Validated tab-delimited cache schema parsed strictly as data instead of sourced shell assignments.
- Locally generated bounded benchmark fixtures and independent candidate/capacity orchestration.
- Hardware-signature cache reuse independent of render-node assignment.
- Argument arrays grouped by FFmpeg phase with a fixed `-f mpegts pipe:1` destination.
- Streaming diagnostic redaction kept separate from media stdout.
- Black-box tests assert observable commands, status codes, output policy, pipe replay, and managed-integration contracts rather than inherited helper structure.

## Overlap review

On 2026-08-29, normalized exact-line comparison against the inherited baseline found:

- core replacement (`ffmpeg-smart.sh` plus `lib/*.sh`): zero identical non-comment lines of 48 or more characters;
- core replacement at a 32-character threshold: two common shell-mechanics lines (`BASH_SUBSHELL` protection and one environment-case arm);
- all shell files at a 48-character threshold: nine identical lines, all in retained project validation/version plumbing rather than runtime or benchmark implementation.

No non-trivial identical runtime block was found. The branch does not add an MIT license or claim that relicensing/release is complete; that remains a separate approval and legal-review gate.
