{ pkgs ? import <nixpkgs> {} }:
  pkgs.mkShell {
    # nativeBuildInputs is usually what you want -- tools you need to run
    nativeBuildInputs = with pkgs.buildPackages; [ 
      dotnetCorePackages.sdk_9_0
    ];

    shellHook = ''
    
    '';
}
