{
  config,
  flake-parts-lib,
  inputs,
  lib,
  self,
  ...
}:
{
  options =
    let
      inherit (flake-parts-lib) importApply;
      inherit (lib.options) mkOption;
      inherit (lib.types) submoduleWith;
    in
    {
      packageSets = mkOption {
        description = "The project-level [`packageSets`](#opt-packageSets) configuration.";
        default = { };
        type = submoduleWith {
          modules = [ (importApply ./modules/packageSets.nix { inherit inputs importApply self; }) ];
        };
      };
    };

  # TODO: Not compatible with overlayAttrs. How do I warn or assert that they should not be populated simultaneously?
  # I can't use or compare `config.overlayAttrs` because it'll yield an infinite recursion error.
  config =
    let
      inherit (lib.asserts) assertMsg;
      inherit (lib.attrsets)
        attrNames
        attrValues
        concatMapAttrs
        filterAttrs
        genAttrs
        getAttrFromPath
        mapAttrsToList
        optionalAttrs
        ;
      inherit (lib.filesystem) packagesFromDirectoryRecursive;
      inherit (lib.fixedPoints) composeManyExtensions;
      inherit (lib.modules) mkIf;

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

      enabledStrategies = filterAttrs (
        name:
        assert assertMsg (
          name != "default"
        ) "packageSets.strategies: 'default' is a reserved name and cannot be used as a strategy name.";
        { directory, enable, ... }:
        assert assertMsg (
          enable -> builtins.pathExists directory
        ) "packageSets.strategies: ${name} is enabled but provided directory does not exist: ${directory}.";
        enable
      ) config.packageSets.strategies;
    in
    mkIf config.packageSets.enable {
      flake.overlays =
        let
          overlaysToAddToFlake = concatMapAttrs (
            name: { addToOverlays, overlay, ... }: optionalAttrs addToOverlays { ${name} = overlay; }
          ) enabledStrategies;
        in
        overlaysToAddToFlake // { default = composeManyExtensions (attrValues overlaysToAddToFlake); };

      perSystem =
        args@{ pkgs, system, ... }:
        let
          inherit (config.packageSets.nixpkgs)
            enable
            extraConfig
            extraOverlays
            input
            setModulePkgsArg
            ;

          enabledOverlays = mapAttrsToList (_: { overlay, ... }: overlay) enabledStrategies;

          pkgs' =
            if enable then
              builtins.import input {
                inherit system;
                config = extraConfig;
                overlays = extraOverlays ++ enabledOverlays;
              }
            else
              args.pkgs.appendOverlays enabledOverlays;
        in
        {
          _module.args.pkgs = mkIf (enable && setModulePkgsArg) pkgs';

          packages = concatMapAttrs (
            _:
            { directory, packageSetAttributePath, ... }:
            packagesFromPackageSet pkgs' directory packageSetAttributePath
          ) enabledStrategies;
        };
    };
}
