# Architecture Decisions

# ADR-001: Operate as a hybrid maintained fork

## Status

Accepted

## Date

2026-08-22

## Decision

Use the standalone `main`/`dev` lifecycle for matrix2669 development while retaining the GitHub fork relationship, the `upstream` remote, and a clean optional contribution lane. Fork-owned work uses branches based on `dev`. Any upstream candidate uses a focused `contrib/*` branch based directly on freshly reviewed `upstream/main`.

## Reason

The matrix2669 stable line is already substantially ahead of upstream and is the canonical source for the related Dispatcharr plugin. Upstream is not archived, so selected contributions and future synchronization should remain possible without making ongoing fork development depend on maintainer activity.

## Alternatives considered

- Reset `main` to upstream and use the legacy production-overlay workflow, which would discard the established canonical branch meaning and complicate downstream source pins.
- Detach the GitHub fork into an unrelated standalone repository, which would obscure provenance and make upstream comparison harder.
- Submit upstream pull requests from the customized `main` history, which would include unrelated fork changes.

## Consequences

The fork can release and evolve independently. Upstream-bound changes require a deliberate clean transplant and refreshed upstream review. Applicable upstream changes must be evaluated and integrated into `dev` rather than assumed to arrive automatically.

# ADR-002: Use semantic project versions

## Status

Accepted

## Date

2026-08-22

## Decision

Use root `VERSION` as the canonical semantic version and keep the embedded script version synchronized. Stable versions use `vMAJOR.MINOR.PATCH` tags; beta versions use `vMAJOR.MINOR.PATCH-beta.N`.

The historical tracked post-commit hook that rewrote the script version to an abbreviated commit is removed because it conflicts with immutable semantic release metadata. Downstream integrations continue to pin the full Git commit and checksum independently of the human-facing version.

## Reason

A stable project identity is useful to users, while the plugin's full commit and checksum provide stronger source traceability than an embedded abbreviated commit.

## Consequences

Version changes must update both version sources and the changelog. Cache fingerprints include the embedded version, so a new version can deliberately invalidate stale capability cache state.

# ADR-003: Do not infer a license for inherited code

## Status

Accepted

## Date

2026-08-22

## Decision

Preserve upstream provenance and do not add a repository-wide license, publish a GitHub Release, or attach a distributable project ZIP until the upstream copyright holder explicitly licenses the inherited code. A normal Git tag may identify an immutable project state but does not claim or grant redistribution rights.

## Reason

At the recorded upstream review, the repository contained no license. Upstream pull request #2 proposes MIT but remains unmerged. The fork cannot unilaterally relicense inherited work.

## Consequences

`v1.0.0` may be tagged without a GitHub Release. Release packaging remains blocked pending upstream authorization; once resolved, this decision and `RELEASE.md` must be updated before publication.
