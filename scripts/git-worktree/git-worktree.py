#!/usr/bin/env python3
"""Interactive task workspaces containing one Git worktree per repository."""
import argparse
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys


class Error(Exception):
    pass


def run(*args, cwd=None, check=True):
    result = subprocess.run(args, cwd=cwd, text=True, capture_output=True)
    if check and result.returncode:
        raise Error(result.stderr.strip() or result.stdout.strip() or f"Command failed: {args[0]}")
    return result


def git(repo, *args, check=True):
    return run("git", "-C", str(repo), *args, check=check)


def ask(label, default=None):
    value = input(f"{label}" + (f" [{default}]" if default is not None else "") + ": ").strip()
    return value or default or ""


def yes(label):
    return ask(label + " (y/N)").lower() in ("y", "yes")


def default_branch(repo):
    # Ask the remote first: a cached origin/HEAD may have become stale.
    remote = git(repo, "ls-remote", "--symref", "origin", "HEAD", check=False)
    match = re.search(r"^ref: refs/heads/(.+)\tHEAD$", remote.stdout, re.M)
    if match:
        return "origin/" + match[1]
    cached = git(repo, "symbolic-ref", "--short", "refs/remotes/origin/HEAD", check=False)
    if cached.returncode == 0:
        print("Origin is unreachable: using the locally cached default branch.")
        return cached.stdout.strip()
    print("Remote default branch unavailable: specify a starting branch.")
    return None


def revision_file(repo, revision, filename):
    result = git(repo, "show", f"{revision}:{filename}", check=False)
    return result.stdout if result.returncode == 0 else ""


def project_environment(repo, revision):
    prefix = ""
    raw = revision_file(repo, revision, "package.json")
    if not raw:
        files = git(repo, "ls-tree", "-r", "--name-only", revision).stdout.splitlines()
        manifests = [name for name in files if name.endswith("/package.json")
                     and not set(Path(name).parts).intersection({".github", "node_modules", "vendor"})]
        if not manifests:
            return {"node": None, "manager": None, "requestedNode": None}
        print("Nested package.json files: " + ", ".join(manifests))
        selected = ask("package.json to use for the environment", manifests[0])
        if selected not in manifests:
            raise Error("Choose one of the listed package.json files.")
        prefix = str(Path(selected).parent) + "/"
        raw = revision_file(repo, revision, selected)
    package = json.loads(raw)
    requested = None
    for filename in (".nvmrc", ".node-version"):
        value = revision_file(repo, revision, prefix + filename).strip()
        if value:
            requested = value
            break
    if not requested:
        tool_versions = revision_file(repo, revision, prefix + ".tool-versions")
        match = re.search(r"^nodejs\s+(\S+)", tool_versions, re.M)
        requested = match[1] if match else (package.get("volta") or {}).get("node")
    requested = requested or (package.get("engines") or {}).get("node")
    if requested:
        # Use the first declared major, including common minimum/caret ranges.
        match = re.match(r"(?:v|[~^]|>=?\s*)?(\d+)(?=\.|\s|\||$)", requested)
        if not match:
            raise Error(f"Cannot determine a Node major from {requested!r}; declare a numeric version in the project.")
        major = match[1]
        print(f"Project Node requirement: {requested}. Nix uses the patch available for this major in the lock.")
    else:
        major = ask("Node major version for the Nix shell")
    if not re.fullmatch(r"[1-9]\d*", major):
        raise Error("Specify a numeric Node major version (e.g. 20).")

    manager = package.get("packageManager")
    if not manager:
        volta = package.get("volta") or {}
        for name in ("pnpm", "yarn", "npm"):
            if name in volta:
                manager = f"{name}@{volta[name]}"
                break
    if not manager:
        locks = []
        for filename, name in (("pnpm-lock.yaml", "pnpm"), ("yarn.lock", "yarn"),
                               ("package-lock.json", "npm"), ("npm-shrinkwrap.json", "npm")):
            content = revision_file(repo, revision, prefix + filename)
            if content:
                locks.append("yarn@1.22.22" if name == "yarn" and "# yarn lockfile v1" in content else name)
        locks = list(dict.fromkeys(locks))
        if len(locks) == 1:
            manager = locks[0]
        elif locks:
            print("Multiple lockfiles: " + ", ".join(locks))
    if not manager or manager in ("pnpm", "yarn"):
        manager = ask("Package manager (npm, or pnpm@version / yarn@version)", manager or "npm")
    if not re.fullmatch(r"(?:npm|pnpm|yarn)(?:@\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+sha\d+\.[0-9a-fA-F]+)?)?", manager):
        raise Error("Invalid package manager: use name@version, e.g. pnpm@9.4.0.")
    if manager in ("pnpm", "yarn"):
        raise Error("Specify the package manager version to make the environment reproducible.")
    print(f"Package manager: {manager}")
    return {"node": int(major), "manager": manager, "requestedNode": requested}


def nix_string(value):
    return json.dumps(value, ensure_ascii=False).replace("${", "\\${")


def render_flake(projects):
    legacy = any(p["node"] in (18, 20) for p in projects.values())
    ancient = any(p["node"] == 16 for p in projects.values())
    inputs = '  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";\n'
    if legacy:
        inputs += '  inputs.nodeLegacy.url = "github:NixOS/nixpkgs/nixos-24.11";\n'
    if ancient:
        inputs += '  inputs.node16.url = "github:NixOS/nixpkgs/nixos-23.11";\n'
    shells = []
    for name, project in projects.items():
        major, manager = project["node"], project["manager"]
        source = "inputs.node16" if major == 16 else "inputs.nodeLegacy" if major in (18, 20) else "inputs.nixpkgs"
        node = f'(import {source} {{ inherit system; }}).nodejs_{major}' if major else None
        tools = "[ pkgs.git ]"
        if node:
            tools = f"[ pkgs.git {node} ]"
        if manager and manager != "npm":
            command = manager.split("@", 1)[0]
            # Explicit Corepack version selection does not modify package.json.
            wrapper = f'pkgs.writeShellScriptBin {nix_string(command)} {nix_string(f"exec ${{pkgs.corepack}}/bin/corepack {shlex.quote(manager)} \"$@\"")}'
            # Keep the Nix interpolation for corepack, while escaping user data.
            wrapper = wrapper.replace(r"\${pkgs.corepack}", "${pkgs.corepack}")
            tools = f"[ ({wrapper}) pkgs.git {node} ]"
        shells.append(f"          {nix_string(name)} = pkgs.mkShell {{ packages = {tools}; }};")
    same = len({(p["node"], p["manager"]) for p in projects.values()}) == 1
    default = f"shells.{nix_string(next(iter(projects)))}" if same else "pkgs.mkShell { packages = [ pkgs.git ]; }"
    return """{
  description = "Generated development shells for a worktree workspace";
""" + inputs + """  outputs = inputs@{ self, nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    in {
      devShells = nixpkgs.lib.genAttrs systems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          shells = {
""" + "\n".join(shells) + "\n          };\n        in shells // { default = " + default + "; });\n    };\n}\n"


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")


def exclude(repo, patterns):
    path = Path(git(repo, "rev-parse", "--path-format=absolute", "--git-path", "info/exclude").stdout.strip())
    path.parent.mkdir(parents=True, exist_ok=True)
    existing = path.read_text() if path.exists() else ""
    missing = [pattern for pattern in patterns if pattern not in existing.splitlines()]
    if missing:
        with path.open("a") as stream:
            stream.write("\n# git-worktree local files\n" + "\n".join(missing) + "\n")


def copy_envs(source, target, worktree_base):
    count = 0
    for root, dirs, files in os.walk(source, followlinks=False):
        dirs[:] = [name for name in dirs if name not in (".git", "node_modules", ".direnv", ".worktree", ".yarn")
                   and not (Path(root) / name).is_symlink()
                   and not (worktree_base.is_relative_to(source)
                            and (Path(root) / name).resolve().is_relative_to(worktree_base))]
        for name in files:
            if name != ".env" and not name.startswith(".env."):
                continue
            src = Path(root) / name
            dst = target / src.relative_to(source)
            # Do not follow checkout symlinks when writing secret files.
            if src.is_symlink():
                raise Error(f"Env symlink cannot be copied: {src}")
            if any(p.is_symlink() for p in (dst, *dst.parents)):
                raise Error(f"Env destination cannot contain symlinks: {dst}")
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(src, dst)
            dst.chmod(0o600)
            count += 1
    exclude(target, [".env", ".env.*"])
    return count


def setup_workspace(task, repo_name, environment, workspace):
    env_dir = task / ".worktree-env"
    env_dir.mkdir(exist_ok=True)
    manifest = env_dir / "projects.json"
    projects = json.loads(manifest.read_text()) if manifest.exists() else {}
    projects[repo_name] = environment
    flake = env_dir / "flake.nix"
    previous = flake.read_text() if flake.exists() else None
    flake.write_text(render_flake(projects))
    try:
        run("nix", "flake", "lock", f"path:{env_dir}")
        system = run("nix", "eval", "--impure", "--raw", "--expr", "builtins.currentSystem").stdout.strip()
        # Evaluate all shells, including old projects after updating the workspace.
        for name in projects:
            run("nix", "eval", "--raw", f'path:{env_dir}#devShells.{system}.{nix_string(name)}.drvPath')
    except Error:
        if previous is None:
            flake.unlink()
        else:
            flake.write_text(previous)
        raise
    write_json(manifest, projects)
    legacy_workspace = task / "task.code-workspace"
    source = workspace if workspace.exists() else legacy_workspace
    document = json.loads(source.read_text()) if source.exists() else {"folders": []}
    folders = document.setdefault("folders", [])
    if not any(folder.get("path") == repo_name for folder in folders):
        folders.append({"name": repo_name, "path": repo_name})
    write_json(workspace, document)
    generated = []
    shared_dotenv = ('dotenv "$HOME/Projects/DaVinci/.env"\n'
                     if task.resolve().is_relative_to((Path.home() / "Projects/DaVinci").resolve())
                     else "")
    for directory, shell in ((task, "default"), (task / repo_name, repo_name)):
        envrc = directory / ".envrc"
        marker = "# Generated by git-worktree\n"
        if envrc.is_symlink() or (envrc.exists() and not envrc.read_text().startswith(marker)):
            print(f"Keeping existing .envrc: {envrc}; authorize it manually if needed.")
            continue
        relative = os.path.relpath(env_dir, directory)
        attribute = shell if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_-]*", shell) else nix_string(shell)
        reference = f"path:{relative}#{attribute}"
        envrc.write_text(marker + f"watch_file {shlex.quote(relative + '/flake.nix')}\n"
                         + f"watch_file {shlex.quote(relative + '/flake.lock')}\n"
                         + f"use flake {shlex.quote(reference)}\n"
                         + shared_dotenv)
        generated.append(directory)
    for directory in generated:
        run("direnv", "allow", str(directory))
    if len({(p["node"], p["manager"]) for p in projects.values()}) > 1:
        print("Different environments: enter each repository to activate its Node/package manager version.")
    if legacy_workspace != workspace:
        legacy_workspace.unlink(missing_ok=True)
    return workspace


def main():
    parser = argparse.ArgumentParser(prog="git-worktree", description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path.cwd(), help="Repository (default: current directory)")
    args = parser.parse_args()
    repo = Path(git(args.repo, "rev-parse", "--show-toplevel").stdout.strip()).resolve()
    common = Path(git(repo, "rev-parse", "--path-format=absolute", "--git-common-dir").stdout.strip())
    auto_push = git(repo, "config", "--type=bool", "--get-all", "push.autoSetupRemote", check=False)
    # Git's push config callback ORs true into a flag; a later false does not
    # clear it. Reject this case instead of claiming a protection that fails.
    if "true" in auto_push.stdout.splitlines():
        raise Error("push.autoSetupRemote=true is set in Git configuration: remove that setting "
                    "before proceeding to require --set-upstream on the first push.")
    if git(repo, "config", "--get-all", "remote.origin.push", check=False).stdout.strip():
        raise Error("Origin has explicit push refspecs: remove them to enable the upstream check.")
    if git(repo, "config", "--local", "--get", "core.worktree", check=False).stdout.strip():
        raise Error("Repositories with explicit core.worktree are unsupported: use a standard checkout.")
    repo_name = common.parent.name if common.name == ".git" else repo.name
    if repo_name in ("default", ".worktree-env", "task.code-workspace"):
        raise Error("Repository name is reserved for workspace files.")
    branch = ask("New branch name")
    git(repo, "check-ref-format", "--branch", branch)
    if git(repo, "show-ref", "--verify", f"refs/heads/{branch}", check=False).returncode == 0:
        raise Error(f"Branch {branch} already exists; choose a new name.")
    base = ask("Starting branch", default_branch(repo))
    if not base or base.startswith("-"):
        raise Error("Invalid starting branch.")
    if base.startswith("origin/"):
        git(repo, "fetch", "origin", f"refs/heads/{base[7:]}:refs/remotes/{base}")
    revision = git(repo, "rev-parse", "--verify", f"{base}^{{commit}}").stdout.strip()
    root_input = Path(ask("Worktree directory (relative to the repository root)", "../.worktree")).expanduser()
    root = (repo / root_input).resolve()
    task = root / branch
    workspace = task / (branch.replace("/", "-") + ".code-workspace")
    target = task / repo_name
    if target == workspace:
        raise Error("Repository name conflicts with the workspace filename.")
    if not task.resolve().is_relative_to(root):
        raise Error("The task path escapes the worktree directory through a symlink.")
    if target.exists() or target.is_symlink():
        raise Error(f"Destination already exists: {target}")
    if repo.is_relative_to(task):
        raise Error("The task directory cannot contain the source repository.")
    # Prevent conflicting task paths when branch names contain slashes.
    for parent in task.parents:
        if parent == root.parent:
            break
        if (parent / ".worktree-env").exists():
            raise Error(f"This path is inside another task: {parent}")
    environment = project_environment(repo, revision)
    task.mkdir(parents=True, exist_ok=True)
    env_dir = task / ".worktree-env"
    if env_dir.is_symlink():
        raise Error("The .worktree-env directory cannot be a symlink.")
    for path in (workspace, task / "task.code-workspace", *(env_dir / name for name in ("flake.nix", "flake.lock", "projects.json"))):
        if path.is_symlink():
            raise Error(f"Configuration file cannot be a symlink: {path}")
    if root.is_relative_to(repo):
        exclude(repo, ["/" + root.relative_to(repo).as_posix() + "/"])
    backups = {path: path.read_bytes() if path.exists() else None for path in (
        workspace, task / "task.code-workspace", task / ".envrc",
        *(task / ".worktree-env" / name for name in ("flake.nix", "flake.lock", "projects.json"))) }
    git(repo, "-c", "branch.autoSetupMerge=false", "worktree", "add", "--no-track", "-b", branch, str(target), revision)
    try:
        # A simple push must fail without upstream, even with global autoSetupRemote.
        for key in ("remote", "merge"):
            git(repo, "config", "--local", "--unset-all", f"branch.{branch}.{key}", check=False)
        git(repo, "config", f"branch.{branch}.pushRemote", "origin")
        git(repo, "config", "extensions.worktreeConfig", "true")
        git(target, "config", "--worktree", "push.autoSetupRemote", "false")
        git(target, "config", "--worktree", "push.default", "simple")
        git(target, "config", "--worktree", "remote.pushDefault", "origin")
        count = copy_envs(repo, target, root)
        exclude(target, ["/.envrc", "/.direnv/"])
        workspace = setup_workspace(task, repo_name, environment, workspace)
    except (Error, OSError, ValueError, KeyboardInterrupt, EOFError):
        # These files and this branch were created by this invocation only.
        for path, content in backups.items():
            if content is None:
                path.unlink(missing_ok=True)
            else:
                path.write_bytes(content)
        removed = git(repo, "worktree", "remove", "--force", str(target), check=False)
        if removed.returncode == 0:
            git(repo, "branch", "-D", branch, check=False)
        else:
            print(f"Automatic cleanup failed; check {target}.", file=sys.stderr)
        raise
    print(f"Worktree created: {target}")
    print(f"Copied {count} env files; workspace: {workspace}")
    print("First push: " + shlex.join(["git", "push", "--set-upstream", "origin", branch]))
    if yes("Open the workspace in VSCode?"):
        if shutil.which("code"):
            subprocess.Popen(["code", str(workspace)], start_new_session=True)
        else:
            print(f"The code command is unavailable; open {workspace} manually.")


if __name__ == "__main__":
    try:
        main()
    except (Error, OSError, ValueError) as error:
        print(f"Error: {error}", file=sys.stderr)
        sys.exit(1)
    except (KeyboardInterrupt, EOFError):
        print("\nOperation interrupted.", file=sys.stderr)
        sys.exit(130)
