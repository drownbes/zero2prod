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
    treefmt-nix.url = "github:numtide/treefmt-nix";
    crane.url = "github:ipetkov/crane";
    advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };
  };

  outputs = {
    self,
    fenix,
    flake-utils,
    nixpkgs,
    process-compose-flake,
    services-flake,
    treefmt-nix,
    crane,
    advisory-db,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      toolchain = fenix.packages.${system}.stable.completeToolchain;
      pcs = import process-compose-flake.lib {inherit pkgs;};
      postgres-service = pcs.evalModules {
        modules = [
          services-flake.processComposeModules.default
          {
            cli.options.port = 8084;
            services.postgres."pg_master" = {
              enable = true;
              superuser = "postgres";
            };
            services.redis."rd_master" = {
              enable = true;
            };
          }
        ];
      };

      treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;

      processCompose = postgres-service.config.outputs.package;
      platform = pkgs.makeRustPlatform {
        cargo = toolchain;
        rustc = toolchain;
      };

      craneLib' = crane.mkLib pkgs;
      unfilteredRoot = ./.;

      src = with pkgs;
        lib.fileset.toSource {
          root = unfilteredRoot;
          fileset = lib.fileset.unions [
            # Default files from crane (Rust and cargo files)
            (craneLib.fileset.commonCargoSources unfilteredRoot)
            # Also keep any markdown files
            (lib.fileset.fileFilter (file: file.hasExt "html") unfilteredRoot)
            # Example of a folder for images, icons, etc
            # (lib.fileset.maybeMissing ./src/routes/home/home.html)
            # (lib.fileset.maybeMissing ./src/routes/login/login.html)
            (lib.fileset.maybeMissing ./migrations)
            (lib.fileset.maybeMissing ./configuration)
            (lib.fileset.maybeMissing ./.sqlx)
          ];
        };

      craneLib = craneLib'.overrideToolchain toolchain;

      commonArgs = {
        inherit src;
        strictDeps = true;
        doCheck = false;
        nativeBuildInputs = [
          pkgs.pkg-config
        ];

        buildInputs = [
          pkgs.openssl
          pkgs.openssl.dev
        ];
      };

      cargoArtifacts = craneLib.buildDepsOnly (commonArgs
        // {
          SQLX_OFFLINE = true;
        });

      zero2prod-crate = craneLib.buildPackage (commonArgs
        // {
          inherit cargoArtifacts;
          SQLX_OFFLINE = true;
        });

      clippy = craneLib.cargoClippy (commonArgs
        // {
          inherit cargoArtifacts;
          SQLX_OFFLINE = true;
          cargoClippyExtraArgs = "--all-targets -- --deny warnings";
        });

      audit = craneLib.cargoAudit {
        inherit src advisory-db;
      };

      deny = craneLib.cargoDeny {
        inherit src;
      };
      nextest = craneLib.cargoTest (commonArgs
        // {
          inherit cargoArtifacts;
        });

      integration = craneLib.mkCargoDerivation (commonArgs
        // {
          inherit cargoArtifacts;
          pnameSuffix = "-test";
          doCheck = false;
          buildPhaseCargoCommand = ''
            ${processCompose}/bin/process-compose --detached

            cargo test --locked

            ${processCompose}/bin/process-compose down
          '';
        });
    in {
      formatter = treefmtEval.config.build.wrapper;
      checks = {
        inherit clippy integration;
        formatting = treefmtEval.config.build.check self;
      };

      packages = rec {
        inherit integration;
        artifacts = cargoArtifacts;
        project-crane = zero2prod-crate;
        project-docker-image = pkgs.dockerTools.buildImage {
          name = "zero2prod";
          config = {
            Cmd = ["${project}/bin/zero2prod"];
          };
        };

        project = platform.buildRustPackage {
          pname = "zero2prod";
          version = "0.1.0";
          src = ./.;
          cargoLock.lockFile = ./Cargo.lock;

          cargoTestFlags = "--lib --bins";

          nativeBuildInputs = [
            pkgs.pkg-config
          ];

          buildInputs = [
            pkgs.openssl
            pkgs.openssl.dev
          ];
          PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
          SQLX_OFFLINE = true;
        };
      };

      devShells.default = craneLib.devShell {
        checks = {
          clippy = clippy;
        };
        shellHook = ''
          export DATABASE_URL=postgres://drownbes:@localhost:5432/newsletter
        '';
        inputsFrom = [
          postgres-service.config.services.outputs.devShell
          zero2prod-crate
        ];
        buildInputs = with pkgs; [
          cargo-watch
          cargo-tarpaulin
          cargo-audit
          cargo-expand
          cargo-nextest
          cargo-deny
          sqlx-cli
          bunyan-rs
          postgres-service.config.outputs.package
        ];
      };
    });
}
