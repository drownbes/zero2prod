{...}: {
  projectRootFile = "flake.nix";
  programs = {
    alejandra.enable = true;
    rustfmt.enable = true;
    toml-sort.enable = true;
    jsonfmt.enable = true;
    yamlfmt.enable = false; 
  };
}
