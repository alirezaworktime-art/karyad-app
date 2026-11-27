# Contributing

## Workflow

1. Branch from `main`: `feat/<name>`, `fix/<name>`, `chore/<name>`.
2. Push. CI formats the branch (committing `style: dart format` if needed),
   analyzes and runs all tests. The full report is also pushed to the
   branch `ci-logs/<your-branch>` as `ci-report.txt`.
3. Open a pull request when CI is green. One purpose per PR.
4. Merging to `main` builds the release APK.

## Rules

- Domain code (`domain/`) has no Flutter imports and is unit tested.
- New behavior comes with tests; UI flows get a widget test in `test/`.
- User-facing text is Persian; code, comments and commits are English.
- Conventional Commits: `feat(garage): add oil reminder`.
- No secrets in the repo. Signing keys and API keys live in GitHub
  Actions secrets.
