{ pkgs ? import <nixpkgs> {}, lib ? import <lib> {}}:

(pkgs.buildFHSUserEnv {
  name = "FHS shell";
  targetPkgs = pkgs: (with pkgs; [

]);
  runScript = pkgs.writeScript "init.sh" ''
      # echo hello
      # export ENV_VAR=value

      exec bash

  '';
  
}).env