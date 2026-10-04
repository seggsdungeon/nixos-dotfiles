{
  description = "p16s NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    spicetify-nix.url = "github:Gerg-L/spicetify-nix";
    spicetify-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, spicetify-nix, nixpkgs-unstable, ... }:
    let
      pkgs-unstable = import nixpkgs-unstable {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
    in
    {
      nixosConfigurations.p16s = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit spicetify-nix pkgs-unstable; };
        modules = [
          ./configuration.nix
          spicetify-nix.nixosModules.default
          ./spicetify.nix
        ];
      };
    };
}
