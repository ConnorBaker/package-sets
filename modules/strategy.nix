{ mkOptions, projectRoot }:
{ config, lib, ... }:
let
  inherit (lib.options) literalMD;
  inherit (lib.types)
    bool
    listOf
    nonEmptyStr
    pathInStore
    raw
    ;
in
{
  options = mkOptions {
    enable = {
      description = "Whether to enable this strategy.";
      type = bool;
      default = false;
    };
    addToOverlays = {
      description = ''
        Whether to add this overlay to [`flake.overlays`](../options/flake-parts.html#opt-flake.overlays).

        NOTE: Unlike [`addToPackages`](#opt-packageSets.strategies._name_.addToPackages), this option does not impose
        any restrictions on the structure of [`directory`](#opt-packageSets.strategies._name_.directory).
      '';
      type = bool;
      default = true;
    };
    addToPackages = {
      description = ''
        Whether to add the packages in the package set created by
        [`overlay`](#opt-packageSets.strategies._name_.overlay) to
        [`perSystem.packages`](../options/flake-parts.html#opt-perSystem.packages).

        NOTE: Enabling this option requires [`directory`](#opt-packageSets.strategies._name_.directory) to be flat
        enough that `lib.filesystem.packagesFromDirectoryRecursive` will not create nested package sets because
        [`flake.packages`](../options/flake-parts.html#opt-flake.packages) does not support nested package sets.
      '';
      type = bool;
      default = true;
    };
    directory = {
      description = ''
        The directory under which this strategy should look for packages.

        The default value is derived from the
        [`projectRoot`](#opt-packageSets.projectRoot) option and looks for a
        directory of the same name as the strategy.

        NOTE: If [`addToPackages`](#opt-packageSets.strategies._name_.addToPackages) is `true`, the directory must be
        flat enough that `lib.filesystem.packagesFromDirectoryRecursive` will not create nested package sets because
        [`flake.packages`](../options/flake-parts.html#opt-flake.packages) does not support nested package sets.
      '';
      type = pathInStore;
      default = "${projectRoot}/${config._module.args.name}";
      defaultText = "‹self›/‹name›";
    };
    overlay = {
      description = ''
        An overlay to be used in the extension or creation of a Nixpkgs instance in
        [`nixpkgs`](#opt-packageSets.nixpkgs).
      '';
      type = raw;
      default =
        final: prev:
        prev.lib.filesystem.packagesFromDirectoryRecursive {
          inherit (final) callPackage;
          inherit (config) directory;
        };
      defaultText = literalMD ''
        ```nix
        final: prev:
        prev.lib.filesystem.packagesFromDirectoryRecursive {
          inherit (final) callPackage;
          inherit (config) directory;
        }
        ```
      '';
      example = literalMD ''
        ```nix
        _: prev: {
          pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
            (
              pythonFinal: _:
              prev.lib.filesystem.packagesFromDirectoryRecursive {
                inherit (pythonFinal) callPackage;
                inherit (config) directory;
              }
            )
          ];
        };
        ```
      '';
    };
    packageSetAttributePath = {
      description = ''
        The attribute path to a package set created by
        [`overlay`](#opt-packageSets.strategies._name_.overlay).
      '';
      type = listOf nonEmptyStr;
      default = [ ];
      example = [ "python312Packages" ];
    };
  };
}
