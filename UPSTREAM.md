# Upstream Relationship

## Repositories

- Upstream: `https://github.com/FiveBoroughs/ffmpeg-asr.git`
- Maintained fork: `https://github.com/matrix2669/ffmpeg-asr.git`
- Upstream default branch: `main`
- Reviewed upstream commit: `99899d05affa501404ef2d2b926136a80bb87c75`
- Review completed: `2026-08-22T15:25:16Z`
- Fork stable head at review: `1422797653e82034b4726e331fd971969534913c`
- Divergence at review: upstream was zero commits ahead; the fork was 33 commits ahead.

## Reviewed upstream requirements

The complete upstream tree at the reviewed commit contains:

- `.githooks/post-commit`
- `.gitignore`
- `README.md`
- `benchmark-accel.sh`
- `benchmark-live.sh`
- `ffmpeg-smart.sh`

No `AGENT.md`, `AGENTS.md`, `CLAUDE.md`, Copilot/Cursor rules, `CONTRIBUTING`, pull-request template, issue template, `CODEOWNERS`, security policy, CI workflow, dependency manifest, changelog, release guide, or license file was present.

The README requires Bash invocation, FFmpeg, hardware-specific device access where applicable, and the documented capability/benchmark workflow. Upstream records no formatting, signing, changelog, automated-test, or release requirements. Shell syntax and relevant runtime paths must therefore be validated proportionately for any contribution.

## Contribution workflow

1. Fetch all upstream branches with pruning.
2. Confirm the current upstream default branch and commit.
3. Re-scan the complete upstream tree for instructions, contribution guidance, license, CI, security, and governance changes.
4. Review relevant commits, issues, and pull requests for overlap.
5. Create `contrib/<topic>` directly from the refreshed `upstream/main`.
6. Include only the focused upstream-suitable change and its necessary documentation/tests.
7. Validate against upstream behavior and requirements.
8. Refresh the review again immediately before opening the pull request.
9. Target `FiveBoroughs/ffmpeg-asr:main`; never target upstream from the fork's customized `main` or `dev`.

If current upstream state cannot be verified, stop the contribution rather than relying on this cached review.

## Current overlap and licensing

- Upstream pull request #2 proposes an MIT license and remains open. The maintained fork has asked the copyright holder to review or clarify it.
- Upstream pull request #3 proposes live DASH/HLS VAAPI fixes and must be reviewed before overlapping stream-input work.
- An open license proposal is not permission to relicense inherited code. Until upstream explicitly adopts a license or otherwise grants permission, do not represent the whole fork as MIT-licensed or publish a distributable project Release.
