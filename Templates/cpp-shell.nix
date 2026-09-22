{
  pkgs ? import <nixpkgs> { },
}:

pkgs.mkShell {
  packages = with pkgs; [
    llvmPackages.clang
    llvmPackages.libcxx
    llvmPackages.clang-tools
  ];
}
