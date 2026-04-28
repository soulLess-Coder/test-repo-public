# test-repo-internal

The **private** side of a `neutral-release` end-to-end test, plus the
**Convex deployment that hosts the orchestrator**. Two things live here:

1. The npm package `@release-test/repo` — `src/index.js` is the source,
   `package.json` is the manifest. This is what gets mirrored to
   `test-repo-public` and (eventually) published to npm.
2. A Convex project — `convex/` mounts the `neutral-release` component,
   exposes the GitHub-push webhook, and the worker callback endpoint.

```
test-repo-internal/
├── package.json                       # both: npm manifest + workspace root
├── convex.json                        # Convex project config
├── tsconfig.json
├── README.md
├── .gitignore
├── convex/                            # the orchestrator host (this Convex deployment)
│   ├── convex.config.ts               # registers neutral-release component
│   ├── schema.ts                      # empty (component owns its own tables)
│   ├── http.ts                        # mounts /webhooks/{github/push,release/callback}
│   └── release.ts                     # CLI driver wrappers
├── packages/
│   └── neutral-release/               # the component itself (workspace pkg)
└── src/
    └── index.js                       # the actual @release-test/repo source
```

## How this differs from a real-world setup

In production, the Convex deployment hosting `neutral-release` is its
own separate project — not the same as the source repo being mirrored.
Here we colocate them in one repo for testing convenience. The
`transformConfig` set up by `release:register` excludes `convex/`,
`packages/`, `package.json`, and the various lockfiles from the mirror,
so only `src/` lands in `test-repo-public`.

## End-to-end testing flow

This is the abbreviated version; the full story (with troubleshooting)
is in `../test-repo-public/README.md` plus the comments in
`convex/release.ts`.

### Round 1 — verify ingestion

```bash
# Generate two HMAC secrets (save them somewhere)
PUSH_SECRET=$(openssl rand -hex 32)
CALLBACK_SECRET=$(openssl rand -hex 32)

# Install + bring Convex online (also regenerates _generated/)
bun install
bunx convex dev      # leave running in another terminal

# Register this repo. Replace placeholders with your GitHub user/org.
bunx convex run release:register '{
  "pushSecret":     "<PUSH_SECRET>",
  "callbackSecret": "<CALLBACK_SECRET>",
  "internalRepo":   "<you>/test-repo-internal",
  "externalRepo":   "<you>/test-repo-public"
}'
# → returned repoId (e.g. "10001;repos") — copy it

# Push this directory to GitHub:
git init && git add -A && git commit -m "chore: initial commit"
git branch -M main
git remote add origin git@github.com:<you>/test-repo-internal.git
git push -u origin main

# Configure the webhook on the GitHub repo:
#   Settings → Webhooks → Add webhook
#   URL: https://<deployment>.convex.site/webhooks/github/push
#   Content type: application/json
#   Secret: <PUSH_SECRET>   (same value)
#   Events: just push events

# Push a real commit and verify it lands:
echo "console.log('hi');" >> src/index.js
git commit -am "feat(greeter): add log

Version-Bump: minor"
git push

bunx convex run release:listCommits '{
  "repoId":"<REPO_ID>","branchName":"main","limit":10
}' | jq .
```

### Round 2 — verify planning

```bash
bunx convex run release:baseline '{
  "repoId":"<REPO_ID>","semver":"0.0.0","atCommitSha":"0000000","atTime":0
}'
bunx convex run release:preview '{"repoId":"<REPO_ID>"}' | jq .
bunx convex run release:plan    '{"repoId":"<REPO_ID>"}'
# → versionId, e.g. "10042;versions"
```

### Round 3 — full pipeline (dry-run npm)

See `../test-repo-public/README.md` for the workflow setup, secrets,
and Copybara pinning. Then back here:

```bash
bunx convex env set NEUTRAL_RELEASE_GITHUB_TOKEN <ghp_token>
bunx convex run release:dispatch '{"versionId":"<VERSION_ID>"}'
bunx convex run release:listRuns '{"repoId":"<REPO_ID>"}' | jq .
```

## Driver reference

All wrappers live in `convex/release.ts`:

| Wrapper | Calls component function |
| --- | --- |
| `release:register` | `repos.registerRepo` |
| `release:getRepo` / `listRepos` | `repos.getRepo` / `listRepos` |
| `release:baseline` | `versions.setBaselineVersion` |
| `release:preview` | `versions.previewRelease` |
| `release:plan` | `versions.planRelease` |
| `release:dispatch` | `worker.dispatchMirrorRun` |
| `release:cancel` | `worker.cancelMirrorRun` |
| `release:listRuns` | `worker.listMirrorRunsForRepo` |
| `release:getCommit` / `listCommits` | `commits.getCommit` / `listCommitsForBranch` |

## Commit message conventions

The component parses [Conventional Commits] plus four custom trailers:
`Mirror-Visibility`, `Mirror-Strategy`, `Version-Bump`, `Release-Notes`.

```
feat(greeter): add a console.log
fix: handle null name
feat!: drop legacy API
chore: lockfile

# With explicit policy:
feat(greeter): add a flag

Mirror-Visibility: public
Version-Bump: minor
Release-Notes: Adds a flag for verbose output.
```

Pushes to off-allowlist branches (anything not in `mirroredBranches`)
are recorded but forced to `derivedMirrorVisibility: "private"` and
won't shape any public release.

## Component tests

The neutral-release component ships its own test suite:

```bash
cd packages/neutral-release && bun run test    # 108 tests
```

[Conventional Commits]: https://www.conventionalcommits.org/
