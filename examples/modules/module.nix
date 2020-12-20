{ nixpkgs, utils, lib, config, ... }: with lib; {
  options = with types; let
    function = mkOptionType {
      name = "function";
      check = isFunction;
    };
  in {
    overlays = mkOption {
      type = listOf unspecified;
      default = [ ];
    };

    systems = mkOption {
      type = listOf str;
      default = [ "x86_64-linux" ];
    };

    packages = mkOption {
      type = function;
    };

    defaultPackage = mkOption {
      type = function;
    };

    outputs = {
      packages = mkOption {
        type = attrsOf (attrsOf package);
      };
      defaultPackage = mkOption {
        type = attrsOf package;
      };
    };
  };

  config = {
    outputs = utils.eachSystem config.systems (system: let
      inherit (nixpkgs.legacyPackages.${system})
        callPackages
        callPackage;
      packages = callPackages config.packages {};
    in {
      inherit packages;
      defaultPackage = config.defaultPackage packages;
    });
  };
}
