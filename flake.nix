{
  description = "A flake for parsek";
  inputs = {
    flake-parts = {
      inputs.nixpkgs-lib.follows = "nixpkgs";
      url = "github:hercules-ci/flake-parts";
    };
    git-hooks-nix = {
      inputs = {
        nixpkgs-stable.follows = "nixpkgs";
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:cachix/git-hooks.nix";
    };
    nixpkgs.url = "github:NixOS/nixpkgs";
    treefmt-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:numtide/treefmt-nix";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      imports = [
        inputs.git-hooks-nix.flakeModule
        inputs.treefmt-nix.flakeModule
        ./flake-module.nix
      ];

      flake =
        { config, ... }:
        {
          flakeModule = config.flakeModules.default;
          flakeModules.default = ./flake-module.nix;
        };

      packageSets = {
        nixpkgs = {
          enable = true;
          setModulePkgsArg = true;
        };
        strategies = {
          packages.enable = true;
          packages2 =
            { config, ... }:
            {
              enable = true;
              directory = ./packages2;
              # Can specify the overlay manually to change the package set attribute path,
              # or the way the overlay is created.
              overlay = final: prev: {
                cool.new.scope = prev.lib.filesystem.packagesFromDirectoryRecursive {
                  inherit (final) callPackage;
                  inherit (config) directory;
                };
              };
              packageSetAttributePath = [
                "cool"
                "new"
                "scope"
              ];
            };
          packages3 = {
            enable = true;
            addToOverlays = false;
            directory = ./packagesHidingInHere/packages3;
            # No need to specify the overlay if we're adding directly to the package set
            # overlay = final: prev: prev.lib.filesystem.packagesFromDirectoryRecursive {
            #   inherit (final) callPackage;
            #   inherit (config) directory;
            # };
          };
        };
      };

      perSystem =
        { config, ... }:
        {
          pre-commit.settings.hooks = {
            nil.enable = true;
            treefmt = {
              enable = true;
              package = config.treefmt.build.wrapper;
            };
          };

          treefmt = {
            projectRootFile = "flake.nix";
            programs = {
              # Nix
              deadnix.enable = true;
              nixfmt-rfc-style.enable = true;
              statix.enable = true;
              # JSON, Markdown, YAML
              prettier = {
                enable = true;
                includes = [
                  "*.json"
                  "*.md"
                  "*.yaml"
                ];
                settings = {
                  embeddedLanguageFormatting = "auto";
                  printWidth = 120;
                  tabWidth = 2;
                };
              };
            };
          };
        };
    };
}
