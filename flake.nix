{
  description = "MCP-Reborn development environment for Minecraft 1.21";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        jdk = pkgs.jdk21;

        # Native libraries needed for LWJGL 3.x / OpenGL / OpenAL
        nativeLibs = with pkgs; [
          # X11 libraries
          xorg.libX11
          xorg.libXext
          xorg.libXcursor
          xorg.libXrandr
          xorg.libXxf86vm
          xorg.libXi
          xorg.libXinerama
          xorg.libXrender
          xorg.libXtst

          # OpenGL
          libGL
          libglvnd
          mesa

          # Audio
          openal
          libpulseaudio
          alsa-lib
          flite  # Text-to-speech for narrator

          # GLFW dependencies (LWJGL 3 uses GLFW)
          glfw

          # Other
          udev
          libxkbcommon
        ];

        nativeLibPath = pkgs.lib.makeLibraryPath nativeLibs;

        # Wrapper script to run the client
        runClient = pkgs.writeShellApplication {
          name = "mcp-reborn";
          runtimeInputs = [ jdk pkgs.gradle ] ++ nativeLibs;
          text = ''
            export JAVA_HOME="${jdk}"
            export LD_LIBRARY_PATH="${nativeLibPath}:''${LD_LIBRARY_PATH:-}"
            export GRADLE_OPTS="-Xmx6G"

            PROJECT_DIR="''${MCP_REBORN_DIR:-$(pwd)}"

            if [[ ! -f "$PROJECT_DIR/gradlew" ]]; then
              echo "Error: Run this from the MCP-Reborn project directory"
              echo "Or set MCP_REBORN_DIR to the project path"
              exit 1
            fi

            cd "$PROJECT_DIR"
            ./gradlew runclient "$@"
          '';
        };

      in {
        packages.default = runClient;
        packages.prismlauncher = pkgs.prismlauncher;

        apps.default = {
          type = "app";
          program = "${runClient}/bin/mcp-reborn";
        };

        apps.prism = {
          type = "app";
          program = "${pkgs.prismlauncher}/bin/prismlauncher";
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            jdk
            pkgs.gradle
          ] ++ nativeLibs;

          shellHook = ''
            export JAVA_HOME="${jdk}"
            export PATH="${jdk}/bin:$PATH"
            export LD_LIBRARY_PATH="${nativeLibPath}:$LD_LIBRARY_PATH"

            # Gradle settings
            export GRADLE_OPTS="-Xmx6G"

            echo "MCP-Reborn development environment"
            echo "Java: $(java -version 2>&1 | head -1)"
            echo ""
            echo "To generate source code, run:"
            echo "  ./gradlew setup"
            echo ""
            echo "To run the client:"
            echo "  ./gradlew runclient"
            echo "  nix run"
          '';
        };
      }
    );
}
