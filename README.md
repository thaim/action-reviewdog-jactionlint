# action-reviewdog-jactionlint

[![Test](https://github.com/thaim/action-reviewdog-jactionlint/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/thaim/action-reviewdog-jactionlint/actions/workflows/test.yml?query=branch%3Amain)
[![reviewdog](https://github.com/thaim/action-reviewdog-jactionlint/actions/workflows/reviewdog.yml/badge.svg?branch=main)](https://github.com/thaim/action-reviewdog-jactionlint/actions/workflows/reviewdog.yml?query=branch%3Amain)
[![release](https://github.com/thaim/action-reviewdog-jactionlint/actions/workflows/release.yml/badge.svg?branch=main)](https://github.com/thaim/action-reviewdog-jactionlint/actions/workflows/release.yml?query=branch%3Amain)
[![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/thaim/action-reviewdog-jactionlint?logo=github&sort=semver)](https://github.com/thaim/action-reviewdog-jactionlint/releases)

This action runs [jdx/jactionlint](https://github.com/jdx/jactionlint) with [reviewdog](https://github.com/reviewdog/reviewdog) on pull requests.

jdx/jactionlint is a maintained fork of [rhysd/actionlint](https://github.com/rhysd/actionlint).
Several forks of rhysd/actionlint are active, and [reviewdog/action-actionlint](https://github.com/reviewdog/action-actionlint) runs another one, [kjanat/actionlint](https://github.com/kjanat/actionlint).
Use this action to run jdx/jactionlint, which adds security and policy rules on top of the checks of rhysd/actionlint.

The action installs the jdx/jactionlint release binary after checking it against the checksums of the release, and passes the SARIF output of jdx/jactionlint to reviewdog.
It runs on Linux, macOS and Windows runners.

## Input

```yaml
inputs:
  github_token:
    description: 'GITHUB_TOKEN.'
    default: '${{ github.token }}'
  workdir:
    description: 'Working directory relative to the root directory.'
    default: '.'
  tool_name:
    description: 'Tool name to use for reviewdog reporter.'
    default: 'jactionlint'
  ### Flags for reviewdog ###
  level:
    description: 'Report level for reviewdog [info,warning,error]'
    default: 'error'
  reporter:
    description: 'Reporter of reviewdog command [github-pr-check,github-pr-review,github-check].'
    default: 'github-pr-check'
  filter_mode:
    description: 'Filtering mode for the reviewdog command [added,diff_context,file,nofilter].'
    default: 'file'
  fail_level:
    description: 'Exit code 1 for reviewdog if it finds at least 1 issue with severity greater than or equal to the given level [none,any,info,warning,error].'
    default: 'none'
  reviewdog_flags:
    description: 'Additional reviewdog flags, separated by whitespace.'
    default: ''
  ### Flags for jdx/jactionlint ###
  jactionlint_version:
    description: 'Version of jdx/jactionlint to install, as an exact X.Y.Z version.'
    default: '2.1.0' # renovate: datasource=github-releases depName=jdx/jactionlint
  profile:
    description: 'Rule profile of jdx/jactionlint [correctness,default,pedantic]. Empty follows the config file.'
    default: ''
  jactionlint_flags:
    description: 'Additional jdx/jactionlint flags, separated by whitespace.'
    default: ''
```

The inputs of reviewdog and `tool_name` have the same names and defaults as reviewdog/action-actionlint.
`reviewdog_flags` and `jactionlint_flags` are split on whitespace without shell evaluation, so a value cannot contain spaces or quotes.
jdx/jactionlint checks the workflows of the git repository even when `workdir` is a subdirectory. To check other files, pass their paths in `jactionlint_flags`.

## Usage

```yaml
name: reviewdog
on: [pull_request]
permissions: {}
jobs:
  jactionlint:
    name: runner / jactionlint
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: thaim/action-reviewdog-jactionlint@<commit SHA> # v0.1.0
        with:
          reporter: github-pr-review
          # Use correctness to get the checks of rhysd/actionlint only.
          profile: correctness
          fail_level: error
```

### Migrating from reviewdog/action-actionlint

- Replace `actionlint_flags` with `jactionlint_flags`. jdx/jactionlint v2 accepts only POSIX/GNU style options, such as `--ignore` instead of `-ignore`. See [the migration guide of jdx/jactionlint](https://github.com/jdx/jactionlint/blob/main/docs/v2-migration.md).
- Set `profile: correctness` to keep the checks of rhysd/actionlint. Without it, the `default` profile of jdx/jactionlint also reports security and policy rules. See [Coming from actionlint](https://github.com/jdx/jactionlint/blob/main/docs/actionlint.md).
- `.github/actionlint.yaml` is still read when `.github/jactionlint.yaml` does not exist.
- `fail_on_error` is not supported. Use `fail_level`.

## Development

### Release

[Songmu/tagpr](https://github.com/Songmu/tagpr) opens a release pull request when a change is merged into `main`, and merging the release pull request tags the version and creates the GitHub Release.
The pull request title follows Conventional Commits, and its type decides the version bump: `feat` bumps the minor version and the `!` marker bumps the major version.
Both workflows come from [thaim/actions](https://github.com/thaim/actions) (`reusable-release.yml` and `reusable-conventional-pr.yml`).

### Lint

This repository lints itself with this action under the `default` profile of jdx/jactionlint, with [reviewdog/action-shellcheck](https://github.com/reviewdog/action-shellcheck) and with [reviewdog/action-misspell](https://github.com/reviewdog/action-misspell).

### Dependencies

Renovate updates the dependencies, including the versions of jdx/jactionlint and reviewdog in `action.yml` through the custom managers in `.github/renovate.json`.
