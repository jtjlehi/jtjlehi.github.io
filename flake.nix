{
  description = "Build the blog";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    utils.url = "github:numtide/flake-utils";
  };
  outputs = { utils, nixpkgs, ... }: utils.lib.eachDefaultSystem (
    system: let
      pkgs = import nixpkgs { inherit system; };
    in {
      devShells.default = pkgs.mkShell {
        nativeBuildInputs = with pkgs; [
          jekyll
          rubyPackages.minima
          rubyPackages.webrick
          rubyPackages.jekyll-feed
          rubyPackages.jekyll-redirect-from
          rubyPackages.github-pages
         ];
      };
    }
  );
}
