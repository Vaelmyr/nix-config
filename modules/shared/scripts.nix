{ pkgs, ... }:

[
    (import ../../scripts/git-worktree { inherit pkgs; })
]
