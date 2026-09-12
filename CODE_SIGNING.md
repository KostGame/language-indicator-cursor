# Code signing policy

## Current status

Public release binaries are currently unsigned. The project is preparing an application for SignPath Foundation Open Source Code Signing.

If the project is approved, the intended provider statement is:

**Free code signing provided by SignPath.io, certificate by SignPath Foundation.**

Until that approval is active, this sentence describes the intended signing provider, not the current signature state of published binaries.

## Scope

Only release artifacts built from this repository are eligible for signing. The primary signed artifact is `language-indicator.exe`, compiled from `language-indicator.ahk` and repository sources by GitHub Actions on GitHub-hosted Windows runners.

The project does not use the signing service to sign unrelated binaries, third-party binaries, or artifacts built outside the documented release workflow.

## Team roles

This repository is currently maintained by one owner.

- Author / committer: [KostGame](https://github.com/KostGame)
- Reviewer: [KostGame](https://github.com/KostGame)
- Signing approver: [KostGame](https://github.com/KostGame)

Changes submitted by contributors who are not committers must be reviewed before merge. Release signing is intended to require manual approval in SignPath.

## Build and release origin

- Source repository: https://github.com/KostGame/language-indicator-cursor
- Release branch: `master`
- Build system: GitHub Actions
- Release runner: GitHub-hosted Windows runner
- Release workflow: `.github/workflows/release.yml`
- Signing must occur after compilation and before release packaging/publication.

The private signing key must not be stored in this repository or checked into source control.

## Product metadata

Release executables must carry consistent Windows version-resource metadata including product name and numeric file/product version. The release workflow and SignPath artifact configuration should reject artifacts that do not match the expected project metadata.

## Privacy policy

See [PRIVACY.md](PRIVACY.md).

This program will not transfer any information to other networked systems unless specifically requested by the user or the person installing or operating it.

## Fork / upstream status

This project is a visible GitHub fork of `yakunins/language-indicator` and preserves the upstream MIT license and attribution.

SignPath Foundation has additional conditions for signing modified upstream projects. In particular, their current policy states that a modified upstream project may be signed under the fork's project certificate only under specific conditions, including requirements related to upstream signed builds. Eligibility of this fork therefore remains subject to SignPath Foundation review before any claim of approval is made.
