# test-repo-public

The **public mirror** side of a `neutral-release` end-to-end test. Push
this directory to a *public* GitHub repo named `test-repo-public` (or
whatever `externalRepo` you registered in `../test-repo-internal/`'s
`release:register` call).

```
test-repo-public/
├── package.json                       # @release-test/repo-public; thin Convex project
├── convex.json
├── tsconfig.json
├── README.md (this file)
├── .gitignore
├── convex/
│   └── schema.ts                      # empty; here so this IS a Convex project
├── .github/
│   └── workflows/
│       └── neutral-release-mirror.yml # fires on repository_dispatch
└── scripts/
    └── neutral-release-callback.sh    # HMAC-signs the worker callback
```

## How this connects to the orchestrator

The orchestrator (the `neutral-release` component) lives in
`../test-repo-internal/` and listens on a Convex deployment hosted from
that project's `convex/` folder. The flow:

1. Someone calls `release:dispatch` on the **internal** Convex
   deployment with a `versionId`.
2. That action POSTs `repository_dispatch` to **this** GitHub repo with
   `event_type: neutral-release-mirror` and a fully-rendered Copybara
   config in the payload.
3. `.github/workflows/neutral-release-mirror.yml` runs, mirrors via
   Copybara, builds, runs `npm publish --dry-run`, then runs
   `scripts/neutral-release-callback.sh`, which HMAC-signs and POSTs
   results to `<internal-deployment>.convex.site/webhooks/release/callback`.
4. That callback inserts a `releases` row, flips the `versions` row to
   `published`, and patches each commit's `externalSha`.

This repo's own `convex/` directory is intentionally minimal — it
exists so the project IS a Convex project (parity with internal), not
because Phase 3 needs anything Convex-side here.

## Setup steps

### 1. Push to a public GitHub repo

```bash
bun install            # installs the convex CLI, etc.
git init && git add -A && git commit -m "chore: bootstrap with neutral-release workflow"
git branch -M main
git remote add origin git@github.com:<you>/test-repo-public.git
git push -u origin main
```

### 2. Create a deploy key for Copybara to clone the internal repo

```bash
ssh-keygen -t ed25519 -C neutral-release-mirror -f /tmp/release-test-key -N ""
```

- `/tmp/release-test-key.pub` (public half) → `<you>/test-repo-internal`'s
  Settings → Deploy keys → **read-only**.
- `/tmp/release-test-key` (private half) → this repo's
  Settings → Secrets → Actions → `INTERNAL_REPO_SSH_KEY`.

### 3. Set the Actions secrets on this repo

Settings → Secrets and variables → Actions:

| Secret | Value |
| --- | --- |
| `INTERNAL_REPO_SSH_KEY` | The private half of the deploy key from step 2 |
| `NEUTRAL_RELEASE_CALLBACK_SECRET` | Same as `repos.workerCallbackSecret` you passed to `release:register` |
| `NPM_TOKEN` | Any non-empty string for dry-run; a real automation token for real publish |

`GITHUB_TOKEN` is provided automatically.

### 4. Pin a real Copybara version

Edit `.github/workflows/neutral-release-mirror.yml` → "Download Copybara"
step. The placeholder URL there `exit 1`s on purpose so you don't
silently run with no Copybara. Browse
https://github.com/google/copybara/releases, pick a recent tag, and
replace the curl command with a working URL.

### 5. (On the internal side) configure the GitHub PAT

In `../test-repo-internal/`:

```bash
bunx convex env set NEUTRAL_RELEASE_GITHUB_TOKEN <ghp_token>
```

The PAT needs `actions: write` and `contents: read` scoped to **this**
public repo so `dispatchMirrorRun` can POST `repository_dispatch`.

## Common gotchas (Phase 3)

| Symptom | Cause |
| --- | --- |
| Workflow won't start at all | PAT lacks `actions: write` or `externalRepo` is misspelled |
| Workflow says "Permission denied (publickey)" cloning internal | `INTERNAL_REPO_SSH_KEY` missing or contains the public half |
| Copybara: "Cannot find any change to migrate" | First run; add `--init-history` to the Run Copybara step temporarily |
| Callback returns 401 | `NEUTRAL_RELEASE_CALLBACK_SECRET` doesn't match `workerCallbackSecret` in Convex |
| Callback returns 400 with `CALLBACK_MISSING_FIELDS` | Workflow's publish step didn't set tarball/integrity outputs (likely an earlier step failed) |

## Going to real npm publish

In `.github/workflows/neutral-release-mirror.yml`'s "Publish to npm"
step, drop `--dry-run`. Set a real automation `NPM_TOKEN`. Adjust the
package name in `package.json` (or override `publicPackage` when
calling `release:register`) to something you actually control. The
flow is otherwise identical.
