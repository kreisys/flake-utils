{
  description = "A very basic flake";

  inputs.utils.url = "path:/Users/kreisys/Werk/kreisys/flake-utils";

  outputs = { self, nixpkgs, utils }: let
    inputsModule = inputsModule {
      _module.args = {
        inherit nixpkgs;
        utils = utils.lib;
      };

      systems = utils.lib.defaultSystems;
    };

    modularFlake = config: (nixpkgs.lib.evalModules {
      modules = [
        ./module.nix
        config
      ];
    }).config.outputs;

  in modularFlake {
    packages = { hello }: { inherit hello; };
    defaultPackage = { hello, ... }: hello;
  };
}
