{
  inputs,
  importApply,
  self,
}:
{ config, lib, ... }:
let
  inherit (lib.attrsets) attrValues mapAttrs;
  inherit (lib.modules) mkDefault;
  inherit (lib.options) literalMD mkOption;
  inherit (lib.trivial) const;
  inherit (lib.types)
    attrsOf
    bool
    pathInStore
    submoduleWith
    ;

  # A utility for creating an attribute set of options
  mkOptions = mapAttrs (const mkOption);
in
{
  options = mkOptions {
    enable = {
      description = "Whether to enable the [`packageSets`](#opt-packageSets) module.";
      type = bool;
      default = builtins.any ({ enable, ... }: enable) (attrValues config.strategies);
      defaultText = literalMD ''
        ```nix
        builtins.any ({ enable, ... }: enable) (attrValues config.packageSets.strategies)
        ```
      '';
    };
    projectRoot = {
      description = ''
        The path to the root of the project.

        This value also serves as the default parent directory under which enabled package sets are located.

        This behavior can be changed at the [`strategy`](#opt-packageSets.strategy)-level by setting the
        [`directory`](#opt-packageSets.strategies._name_.directory) option.
      '';
      type = pathInStore;
      default = self;
      defaultText = "self";
    };
    nixpkgs = {
      description = ''
        The configuration used to extend or create a copy of Nixpkgs for use by the [`packageSets`](#opt-packageSets)
        module.

        When this module is disabled (the default), [`packageSets`](#opt-packageSets) uses the Nixpkgs instance provided
        by the module system's [`pkgs`](../module-arguments.html#pkgs) argument. As a consequence, the Nixpkgs instance
        must be configured ahead of time to handle any [`strategies`](#opt-packageSets.strategies) which
        involve unfree packages, or other non-standard configurations. It is beyond the scope of this module to
        reconfigure an existing Nixpkgs instance with the options provided to the module.

        When this module is disabled (the default), the changes made to the Nixpkgs instance are never propagated, and
        remain local to [`packageSets`](#opt-packageSets). Put another way, packages added by
        [`strategies`](#opt-packageSets.strategies) are not present in the
        [`pkgs`](../module-arguments.html#pkgs) argument available to other modules.

        When this module is enabled, a new Nixpkgs instance is created using the options supplied to this module. This
        approach is useful when [`strategies`](#opt-packageSets.strategies) involve unfree packages, or
        otherwise require Nixpkgs be instantiated with a non-standard configuration.

        When this module is enabled, this module additionally provides the ability to set the
        [`pkgs`](../module-arguments.html#pkgs) argument, ensuring that the changes made by
        [`strategies`](#opt-packageSets.strategies) are available to other modules.

        Regardless of this module being enabled, the overlays provided to
        [`extraOverlays`](#opt-packageSets.nixpkgs.extraOverlays) are never included in the overlays expose in
        [`flake.overlays`](../options/flake-parts.html#opt-flake.overlays). This is to prevent overlays necessitated
        by the current flake from being unintentionally propagated to other flakes.
      '';
      default = { };
      type = submoduleWith { modules = [ (importApply ./nixpkgs.nix { inherit inputs mkOptions; }) ]; };
    };
    strategies = {
      description = ''
        Strategy modules describe:

        - where to look for packages ([`directory`](#opt-packageSets.strategies._name_.directory))
        - an overlay containing the packages ([`overlay`](#opt-packageSets.strategies._name_.overlay))
        - where to retrieve the packages from the result of applying the overlay
          ([`packageSetAttributePath`](#opt-packageSets.strategies._name_.packageSetAttributePath))

        Strategy modules:

        - are used in overlaying an instance of Nixpkgs as described by the options in
          [`nixpkgs`](#opt-packageSets.nixpkgs)
        - create an overlay in [`flake.overlays`](../options/flake-parts.html#opt-flake.overlays) of the same name as
          the strategy
        - create an overlay [`flake.overlays.default`](../options/flake-parts.html#opt-flake.overlays) which is the
          composition of all other overlays, to ease consumption
        - populate [`perSystem.packages`](../options/flake-parts.html#opt-perSystem.packages) with the packages from
          the overlays
      '';
      type = attrsOf (submoduleWith {
        modules = [
          (importApply ./strategy.nix {
            inherit (config) projectRoot;
            inherit mkOptions;
          })
        ];
      });
      default = { };
      # NOTE: When updating `config.strategies` below, make sure to strip mkDefault as it is an implementation detail.
      defaultText = literalMD ''
        ```nix
        {
          packages = { };
          python-packages =
            { config, ... }:
            {
              overlay = _: prev: {
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
              packageSetAttributePath = [ "python3Packages" ];
            };
        }
        ```
      '';
    };
  };
  # NOTE: We must define the default values here, as the merging behavior is different when these values are provided
  # in `default`. As an example, if these values were provided by `default`, setting `python-packages.enable = true;`
  # sets `overlay`, `packageSetAttributePath`, and all the other fields back to their default values, rather than
  # using the other values provide by the `default` value.
  config.strategies = {
    packages = { };
    python-packages =
      { config, ... }:
      {
        overlay = mkDefault (
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
          }
        );
        packageSetAttributePath = mkDefault [ "python3Packages" ];
      };
  };
}
