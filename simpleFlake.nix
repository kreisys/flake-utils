{ lib }:

let
  # Get what we need out of our own lib so we can reuse the name
  # `lib` as an argument.
  inherit (lib) defaultSystems eachSystem flattenTree;
in
# This function returns a flake outputs-compatible schema.
{ # pass an instance of the nixpkgs flake
  nixpkgs
, # nixpkgs config
  config ? { }
, # pass either a function or a file
  overlay ? (_:_: {})
, # use this to load other flakes overlays to supplement nixpkgs
  preOverlays ? [ ]
, overlays ? preOverlays
, # maps to the devShell output. Pass in a shell.nix file or function.
  devShell ? null
, shell ? devShell
, # pass the list of supported systems
  systems ? defaultSystems
, #
  packages ? null
, #
  hydraJobs ? null
, #
  lib ? null
, #
  nixosModules ? null
}:
let
  inherit (nixpkgs.lib) composeExtensions foldl' pipe flip;

  loadOverlay = flip pipe [
    maybeImport
    (obj: obj.overlay or obj)
  ];

  maybeImport = obj: with builtins;
    if (elem (typeOf obj) [ "path" "string" ]) then
      import obj
    else
      obj
  ;

  overlay' = loadOverlay overlay;
  overlays' = map loadOverlay overlays;
  shell' = maybeImport shell;
  packages' = maybeImport packages;
  hydraJobs' = maybeImport hydraJobs;
  lib' = maybeImport lib;
  nixosModules' = maybeImport nixosModules;
in let
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

    in
    (optionalAttrs (packages' != null) (let
      packages = callPackages packages' {};
      sanitizedPackages = removeAttrs packages [ "defaultPackage" "devShell" ];
    in {
      legacyPackages = sanitizedPackages;

      # Flake expects a flat attrset containing only derivations as values
      packages = flattenTree sanitizedPackages;
    } // (optionalAttrs (packages ? defaultPackage) {
      inherit (packages) defaultPackage;
    }) // (if shell != null then {
      devShell = callPackage shell { };
    } else optionalAttrs (packages ? devShell) {
      inherit (packages) devShell;
    })))
    //
    (optionalAttrs (hydraJobs' != null) {
      hydraJobs = callPackages hydraJobs' {};
    })
    //
    (optionalAttrs (lib' != null) {
      lib = lib';
    })
    // (optionalAttrs (nixosModules' != null) {
      nixosModules = nixosModules';
    }))
    // {
      inherit overlay;
    };
in
outputs
