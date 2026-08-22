# Release Process

## Version rules

- Use Semantic Versioning in root `VERSION` and the `VERSION` constant in `ffmpeg-smart.sh`.
- Prefix Git tags with `v`.
- Use `MAJOR.MINOR.PATCH-beta.N` for beta tags on tested `dev` commits.
- Use `MAJOR.MINOR.PATCH` for stable tags on `main`.
- Never move a published tag or replace a published artifact.
- Downstream consumers continue to pin the exact full Git commit and checksum; a version tag does not replace source verification.

## Validation

Run:

```bash
./scripts/validate.sh
```

Behavioral changes require the applicable live, hardware, cache, container, and real-concurrency checks documented in `AGENT.md`. Inspect the exact tagged tree before publication.

## Beta tag

1. Integrate and validate the intended change on `dev`.
2. Synchronize both version sources and update `CHANGELOG.md`.
3. Tag the exact tested commit as `vMAJOR.MINOR.PATCH-beta.N`.
4. Push the immutable tag.

## Stable tag

1. Promote the exact validated state from `dev` to `main`.
2. Synchronize both version sources and finalize the changelog entry.
3. Run the complete validation gate.
4. Tag the exact `main` commit as `vMAJOR.MINOR.PATCH` and push it.
5. Synchronize `dev` with the stable tagged state.

## GitHub Release and ZIP

Publication is currently blocked because inherited upstream code has no explicit license. Do not create a GitHub Release or distributable project ZIP merely because a stable tag exists.

After the upstream copyright holder explicitly licenses the inherited code:

1. Record and verify the adopted license and update `DECISIONS.md` and `UPSTREAM.md`.
2. Add the authorized license text and attribution.
3. Define and validate an installable archive layout.
4. Publish a normal GitHub Release for a new immutable stable version with the ZIP and SHA-256 checksum attached.
5. Validate the archive from a clean extraction; do not rely only on GitHub's automatic source archive.
