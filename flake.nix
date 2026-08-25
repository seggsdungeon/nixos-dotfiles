{
  description = "p16s NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    spicetify-nix.url = "github:Gerg-L/spicetify-nix";
    spicetify-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, spicetify-nix, ... }: {
    nixosConfigurations.p16s = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit spicetify-nix; };
      modules = [
        ./configuration.nix
        spicetify-nix.nixosModules.default
        ./spicetify.nix
      ];
    };
  };
}
