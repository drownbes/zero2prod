{
  inputs = {
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "nixpkgs/nixos-unstable";
    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
    services-flake.url = "github:juspay/services-flake";
  };

  outputs = { self, fenix, flake-utils, nixpkgs, process-compose-flake,services-flake }: 
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      toolchain = fenix.packages.${system}.stable.completeToolchain;
      pcs = (import process-compose-flake.lib { inherit pkgs; });
    in rec {
      packages = {
        inherit pcs;
        postgres-service = pcs.evalModules {
          modules = [
            services-flake.processComposeModules.default
            {
              cli.options.port = 8084;
              services.postgres."pg_master" = {
                enable = true;
              };
            }
          ];
        };
      };

      devShells.default = pkgs.mkShell {
        shellHook = ''
          export DATABASE_URL=postgres://drownbes:@localhost:5432/newsletter
        '';
        inputsFrom = [
           packages.postgres-service.config.services.outputs.devShell
        ];
        buildInputs = with pkgs;[
          openssl
          pkg-config
          toolchain
          cargo-watch
          cargo-tarpaulin
          cargo-audit
          cargo-expand
          sqlx-cli
          bunyan-rs
          packages.postgres-service.config.outputs.package
        ];
      };
    });
}
