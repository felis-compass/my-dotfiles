{
  pkgs ? import <nixpkgs> { },
}:
pkgs.mkShell.override
  {
    # Override stdenv in order to change compiler:
    # stdenv = pkgs.clangStdenv;
  }
  {
    packages =
      with pkgs;
      [
        clang-tools
        cmake
        codespell
        cppcheck
        doxygen
        gtest
        lcov
        vcpkg
        vcpkg-tool
      ]
      ++ lib.optionals (!stdenv.hostPlatform.isDarwin) [ gdb ];
  }

