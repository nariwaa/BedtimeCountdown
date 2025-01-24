{ pkgs ? import <nixpkgs> {} }:

  pkgs.mkShell {
    buildInputs = with pkgs; [
      file
      flutter319
      android-studio
      android-tools
      sdkmanager
      jdk17
      # openjdk17
      # jdk8
      google-chrome
    ];

  shellHook = ''
#echo -e "\033[33mCreating the flutter venv\033[0m"

echo -e "\033[33m\nDone!\033[0m"
  '';
}
