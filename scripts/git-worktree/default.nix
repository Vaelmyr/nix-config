{ pkgs }:

pkgs.writeShellApplication {
    name = "git-worktree";
    runtimeInputs = [ pkgs.git pkgs.python3 pkgs.nix pkgs.direnv ];
    text = ''
        exec python3 ${./git-worktree.py} "$@"
    '';
}
