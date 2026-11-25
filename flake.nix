{
  description = "Capsaicin の開発・検証ツール（Xcode はホストのものを使う）";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, treefmt-nix, ... }:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs { inherit system; };
      python = pkgs.python3.withPackages (p: [ p.pyyaml ]);
      formatting = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
    in
    {
      formatter.${system} = formatting.config.build.wrapper;
      # CI のビルドのジョブは devShell を評価せず、DMG の見た目を作る dmgbuild だけを入れる（DEC-SYS-028）。
      packages.${system}.dmgbuild = pkgs.python3Packages.dmgbuild;
      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = with pkgs; [
          just
          xcodegen
          swiftformat
          swiftlint
          clang-tools
          prettier
          markdownlint-cli2
          taplo
          shfmt
          shellcheck
          nixfmt
          statix
          deadnix
          lefthook
          gh
          ruff
          python
          python3Packages.dmgbuild
          formatting.config.build.wrapper
        ];
        # Xcode が参照する SDK とツールチェーンはホストに任せる。
        shellHook = ''
          unset DEVELOPER_DIR SDKROOT
        '';
      };
    };
}
