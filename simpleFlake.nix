{ lib }:

let
  # Get what we need out of our own lib so we can reuse the name
  # `lib` as an argument.
  inherit (lib) defaultSystems eachSystem flattenTree;
in
# This function returns a flake outputs-compatible schema.
{ # pass an instance of the nixpkgs flake
  nixpkgs
, # we assume that the name maps to the project name, and also that the
  # overlay has an attribute with the `name` prefix that contains all of the
  # project's packages.
  name
, # nixpkgs config
  config ? { }
, # pass either a function or a file
  overlay ? (_:_: {})
, # use this to load other flakes overlays to supplement nixpkgs
  preOverlays ? [ ]
, overlays ? preOverlays
, # maps to the devShell output. Pass in a shell.nix file or function.
  shell ? null
, # pass the list of supported systems
  systems ? defaultSystems
, #
  packages ? { pkgs }: pkgs.${name} or { }
, #
  lib ? {}
}:
let
  loadOverlay = obj:
    if obj == null then
      [ ]
    else
      [ (maybeImport obj) ]
  ;

  maybeImport = obj: with builtins;
    if (typeOf obj == "path") || (typeOf obj == "string") then
      import obj
    else
      obj
  ;

  overlay' = maybeImport overlay;
  overlays' = map maybeImport overlays;
  shell' = maybeImport shell;
  packages' = maybeImport packages;
in let
  inherit (nixpkgs.lib) composeExtensions foldl';

  shell = shell';

  overlays = overlays' ++ [ overlay' ];

  overlay = foldl' composeExtensions overlay' overlays';

  outputs = eachSystem systems (system:
    let
      pkgs = import nixpkgs {
        inherit
          config
          overlays
          system
          ;
      };

      inherit (nixpkgs.lib) optionalAttrs;
      inherit (pkgs) callPackage callPackages;

      packages = pkgs.callPackages packages' {};
    in
    {
      legacyPackages = packages;
      hydraJobs = packages;

      # Flake expects a flat attrset containing only derivations as values
      packages = flattenTree packages;
    }
    //
    (optionalAttrs (packages ? defaultPackage) {
      inherit (packages) defaultPackage;
    })
    //
    (
      if shell != null then {
        devShell = callPackage shell { };
      } else optionalAttrs (packages ? devShell) {
        inherit (packages) devShell;
      }
    )
  ) // {
    inherit overlay lib;
  };
in
outputs
