# git-worktree

Interactive Git worktrees with shared VSCode workspaces and Nix development
shells. Installed through `modules/shared/scripts.nix`.

```sh
cd ~/Projects/DaVinci/booking-monorepo
git-worktree
```

The command asks for a new branch name, a starting branch (defaulting to the
repository's default branch on `origin`) and a worktree directory. Remote
starting branches are fetched before checkout.

Paths are relative to the repository root. The default `../.worktree` puts
sibling repositories in a shared directory; use `.worktree` to keep worktrees
inside a personal repository. Absolute paths and `~` also work.

```text
<worktree directory>/<branch>/
├── <branch>.code-workspace
├── .envrc
├── .worktree-env/
│   ├── flake.nix
│   ├── flake.lock
│   └── projects.json
└── <repository>/
```

Run it from another repository with the same branch name and worktree directory
to add that repository to the task's workspace. Existing VSCode settings are
preserved. Each run asks whether to open the workspace with `code`; existing
branches and worktree destinations are rejected.
Workspace filenames replace `/` with `-`: `feature/booking` becomes
`feature-booking.code-workspace`.

## Environment

- Copies `.env` and `.env.*`, including nested files, from the source checkout.
  Copies receive `0600` permissions and local Git exclusions; already tracked
  files remain tracked. Dependency folders and worktrees are skipped, and env
  symlinks are rejected. Copied env files are not automatically loaded into the shell.
- Detects Node from `.nvmrc`, `.node-version`, `.tool-versions`, Volta or
  `engines.node`, and the package manager from `packageManager`, Volta or
  lockfiles, using the starting commit. Declared versions are used automatically;
  prompts only request missing information. Common Node ranges use the first
  declared major. Yarn and pnpm require an explicit version.
- Pins the Nix inputs in `flake.lock`. Node uses the selected **major** with the
  patch available in nixpkgs, not necessarily the exact patch in `.nvmrc`.
  Older Node majors use separate nixpkgs inputs. Corepack selects the requested
  package manager version; dependencies are not installed automatically.
- Generates and authorizes `.envrc` files for automatic activation with direnv.
  Existing `.envrc` files are preserved. Different environments activate inside
  each repository; matching environments also activate at the task root.
- Workspaces under `~/Projects/DaVinci` load the shared `~/Projects/DaVinci/.env`
  with `dotenv` after activating the Nix shell, at both task and repository roots.
  This file must exist; its contents are not copied into the generated configuration.

The flake lives in `.worktree-env` so repository files and copied secrets stay
out of the Nix store. Creating the environment requires access to the Nix inputs.

## First push

The worktree shares the original `origin` and starts without an upstream.
A plain `git push` asks you to explicitly set it:

```sh
git push --set-upstream origin <branch>
```

Subsequent pushes work normally. This uses Git's upstream check; explicit push
refspecs can bypass it. Configurations with `push.autoSetupRemote=true`, explicit
`remote.origin.push` refspecs or `core.worktree` are rejected.

## Try before rebuilding

From the `nix-config` directory:

```sh
nix shell nixpkgs#python3 nixpkgs#git nixpkgs#direnv --command \
  python3 scripts/git-worktree/git-worktree.py \
  --repo ~/Projects/DaVinci/booking-monorepo
```
