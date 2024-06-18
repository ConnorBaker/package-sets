{ inputs, mkOptions }:
{ lib, ... }:
let
  inherit (lib.types)
    attrsOf
    bool
    listOf
    pathInStore
    raw
    ;
in
{
  options = mkOptions {
    enable = {
      description = ''
        Whether to enable the instantiation of an entirely new Nixpkgs instance with the given configuration.
      '';
      type = bool;
      default = false;
    };
    input = {
      description = "The Nixpkgs flake input to use.";
      type = pathInStore;
      default = inputs.nixpkgs;
      defaultText = "inputs.nixpkgs";
    };
    extraConfig = {
      description = "Additional Nixpkgs configuration to use.";
      type = attrsOf raw;
      default = { };
    };
    extraOverlays = {
      description = "Overlays to apply prior to this module's overlays.";
      type = listOf raw;
      default = [ ];
    };
    setModulePkgsArg = {
      description = ''
        Replace the Nixpkgs instance provided by the module system's [`pkgs`](../module-arguments.html#pkgs) argument
        with the one created by this module.

        This is useful when other modules in the flake should use the new Nixpkgs instance; for example if they depend
        on the packages added by [`strategies`](#opt-packageSets.strategies).
      '';
      type = bool;
      default = false;
    };
  };
}
