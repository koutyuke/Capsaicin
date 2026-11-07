{ pkgs, ... }:
{
  projectRootFile = "flake.nix";
  programs = {
    clang-format.enable = true;
    prettier.enable = true;
    taplo.enable = true;
    shfmt.enable = true;
    nixfmt.enable = true;
    ruff-format.enable = true;
    just.enable = true;
  };
  settings = {
    global.excludes = [
      "docs/**"
      ".t3-code/**"
      ".build/**"
      "**/.build/**"
      "*.xcodeproj/**"
      ".direnv/**"
      "flake.lock"
      "CLAUDE.md"
      ".agents/skills/**"
      # Icon Composer が書き出すバンドルは生成物なので、整形せずそのまま残す。
      "**/*.icon/**"
      # String Catalog は Xcode が開くたびに独自の形で書き直すので、その形を正とする。
      "*.xcstrings"
    ];
    formatter = {
      # treefmt-nix の swift-format は Apple 製なので、nicklockwood 版を明示する。
      swiftformat = {
        command = "${pkgs.swiftformat}/bin/swiftformat";
        options = [
          "--cache"
          "ignore"
        ];
        includes = [ "*.swift" ];
      };
      prettier.includes = [
        "*.md"
        "*.yml"
        "*.yaml"
        "*.json"
        "*.jsonc"
      ];
    };
  };
}
