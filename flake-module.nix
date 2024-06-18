{
  flake-parts-lib,
  inputs,
  lib,
  self,
  ...
}:
let
  inherit (flake-parts-lib) mkPerSystemOption;
  inherit (lib.attrsets)
    attrNames
    attrValues
    concatMapAttrs
    filterAttrs
    genAttrs
    getAttrFromPath
    mapAttrs
    ;
  inherit (lib.filesystem) packagesFromDirectoryRecursive;
  inherit (lib.lists) map;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkOption;
  inherit (lib.trivial) const throwIfNot;
  inherit (lib.types)
    attrsOf
    bool
    listOf
    literalExpression
    nonEmptyStr
    pathInStore
    raw
    submoduleWith
    ;

  # A utility for creating an attribute set of options
  mkOptions = mapAttrs (const mkOption);

  # Retrieve the packages added by an overlay from a package set
  packagesFromPackageSet =
    pkgs: directory: packageSetAttributePath:
    let
      entries = packagesFromDirectoryRecursive {
        # Needs to match signature of callPackage, though we just want to import the files.
        callPackage = path: _: builtins.import path;
        inherit directory;
      };
    in
    genAttrs (attrNames entries) (name: getAttrFromPath (packageSetAttributePath ++ [ name ]) pkgs);

in
{
  options.perSystem = mkPerSystemOption (
    {
      config,
      pkgs,
      system,
      ...
    }:
    let
      cfg = config.package-sets;
    in
    {
      options.package-sets = mkOption {
        description = "Project-level package-sets configuration";
        default = { };
        type = submoduleWith {
          modules = [
            (
              { config, ... }:
              {
                options = {
                  enable = mkOption {
                    description = "Enable ${config._module.args.name}";
                    type = bool;
                    default = builtins.any ({ enable, ... }: enable) (attrValues cfg.strategies);
                  };
                  project-root = mkOption {
                    type = pathInStore;
                    default = self;
                    defaultText = literalExpression "self";
                    description = "Path to the root of the project";
                  };
                  nixpkgs = mkOptions {
                    input = {
                      type = pathInStore;
                      default = inputs.nixpkgs;
                      description = "Nixpkgs input to use";
                    };
                    config = {
                      type = attrsOf raw;
                      default = { };
                      description = "Nixpkgs configuration to use";
                    };
                    overlays = {
                      type = listOf raw;
                      default = [ ];
                      description = "Extra overlays to use";
                    };
                  };
                  strategies = mkOption {
                    description = "Strategies to use";
                    type = attrsOf (submoduleWith {
                      modules = [
                        (
                          { config, ... }:
                          {
                            options = mkOptions {
                              enable = {
                                description = "Enable the strategy to load ${config._module.args.name}";
                                type = bool;
                                default = false;
                              };
                              directory = {
                                description = "The directory containing packages to add to the overlay";
                                type = pathInStore;
                              };
                              overlay = {
                                description = "An overlay";
                                type = raw;
                              };
                              packageSetAttributePath = {
                                description = "The attribute path to the package set created by `overlay`";
                                type = listOf nonEmptyStr;
                                default = [ ];
                              };
                            };
                          }
                        )
                      ];
                    });
                  };
                };

                config.strategies = {
                  packages =
                    { config, ... }:
                    {
                      directory = "${cfg.project-root}/${config._module.args.name}";
                      overlay =
                        final: prev:
                        prev.lib.filesystem.packagesFromDirectoryRecursive {
                          inherit (final) callPackage;
                          inherit (config) directory;
                        };
                    };

                  python-packages =
                    { config, ... }:
                    {
                      directory = "${cfg.project-root}/${config._module.args.name}";
                      overlay = _final: prev: {
                        pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
                          (
                            pythonFinal: _pythonPrev:
                            prev.lib.filesystem.packagesFromDirectoryRecursive {
                              inherit (pythonFinal) callPackage;
                              inherit (config) directory;
                            }
                          )
                        ];
                      };
                      packageSetAttributePath = [ "python3Packages" ];
                    };
                };
              }
            )
          ];
        };
      };

      config =
        let
          enabledStrategies = filterAttrs (
            name:
            { directory, enable, ... }:
            throwIfNot (enable -> builtins.pathExists directory)
              "package-sets.strategies.${name} is enabled but provided directory does not exist: ${directory}"
              enable
          ) cfg.strategies;
        in
        mkIf cfg.enable {
          _module.args.pkgs = builtins.import cfg.nixpkgs.input {
            inherit (cfg.nixpkgs) config;
            inherit system;
            overlays = cfg.nixpkgs.overlays ++ map ({ overlay, ... }: overlay) (attrValues enabledStrategies);
          };

          packages = concatMapAttrs (
            _:
            { directory, packageSetAttributePath, ... }:
            packagesFromPackageSet pkgs directory packageSetAttributePath
          ) enabledStrategies;
        };
    }
  );
}
