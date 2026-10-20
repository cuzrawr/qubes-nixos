{
  description = "Native Qubes OS templates built with NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
    }:
    let
      system = "x86_64-linux";
      mkBootTest =
        source:
        source.lib.nixosSystem {
          inherit system;
          modules = [
            ./modules/boot.nix
            ./tests/boot.nix
          ];
        };
      stable = mkBootTest nixpkgs;
      unstable = mkBootTest nixpkgs-unstable;
      core = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          self.nixosModules.qubes
          ./tests/core.nix
        ];
      };
      desktop = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          self.nixosModules.qubes
          ./tests/desktop.nix
        ];
      };
      mkTemplateSystem =
        {
          source,
          profile ? ./configuration.nix,
          target ? "nixos",
          input ? "nixpkgs",
        }:
        source.lib.nixosSystem {
          inherit system;
          modules = [
            self.nixosModules.qubes
            ./profiles/base.nix
            profile
            ({ lib, ... }: {
              # retain the pinned nixpkgs source for local evaluation after install.
              nix.registry.nixpkgs.flake = source;
              nix.nixPath = [ "nixpkgs=${source}" ];
              services.qubes.updates.configuration = lib.mkDefault target;
              services.qubes.updates.inputs = lib.mkDefault [ input ];
            })
          ];
        };
      template = mkTemplateSystem { source = nixpkgs; };
      desktopAppmenus = [
        "firefox.desktop"
        "xfce4-terminal.desktop"
        "thunar.desktop"
        "org.xfce.mousepad.desktop"
      ];
      templateUnstable = mkTemplateSystem {
        source = nixpkgs-unstable;
        target = "nixos-unstable";
        input = "nixpkgs-unstable";
      };
      minimal = mkTemplateSystem {
        source = nixpkgs;
        profile = ./configuration-minimal.nix;
        target = "nixos-minimal";
      };
      minimalUnstable = mkTemplateSystem {
        source = nixpkgs-unstable;
        profile = ./configuration-minimal.nix;
        target = "nixos-unstable-minimal";
        input = "nixpkgs-unstable";
      };
      imageWithContents =
        configuration: contents:
        import ./lib/image.nix {
          inherit (configuration) pkgs;
          inherit (configuration.pkgs) lib;
          inherit (configuration) config;
          inherit contents;
        };
      image = configuration: imageWithContents configuration [ ];
      # a writable copy, not an /etc symlink into the immutable store. the same
      # ordinary flake can build the image and rebuild the installed TemplateVM.
      configurationContents = [
        {
          source = self;
          target = "/etc/nixos";
          mode = "u+w";
          user = "root";
          group = "root";
        }
      ];
    in
    {
      nixosModules = {
        qubes = ./modules;
        default = self.nixosModules.qubes;
      };

      overlays.default = import ./pkgs/overlay.nix;

      lib = {
        mkImage = image;
        mkTemplate =
          {
            configuration,
            contents ? [ ],
            ...
          }@args:
          import ./lib/template-rpm.nix (
            (builtins.removeAttrs args [
              "configuration"
              "contents"
            ])
            // {
              inherit (configuration) pkgs;
              image = imageWithContents configuration contents;
            }
          );
      };

      nixosConfigurations = {
        boot-test = stable;
        boot-test-unstable = unstable;
        core-test = core;
        desktop-test = desktop;
        nixos = template;
        nixos-unstable = templateUnstable;
        nixos-minimal = minimal;
        nixos-unstable-minimal = minimalUnstable;
      };

      packages.${system} = (import ./pkgs { inherit (stable) pkgs; }) // rec {
        default = template-rpm;
        template-rpm = self.lib.mkTemplate {
          configuration = template;
          name = "nixos-26.05-xfce";
          release = "2";
          contents = configurationContents;
          appmenus = desktopAppmenus;
        };
        template-rpm-unstable = self.lib.mkTemplate {
          configuration = templateUnstable;
          name = "nixos-unstable-xfce";
          release = "2";
          contents = configurationContents;
          appmenus = desktopAppmenus;
        };
        template-rpm-minimal = self.lib.mkTemplate {
          configuration = minimal;
          name = "nixos-26.05-minimal";
          release = "2";
          contents = configurationContents;
        };
        template-rpm-unstable-minimal = self.lib.mkTemplate {
          configuration = minimalUnstable;
          name = "nixos-unstable-minimal";
          release = "2";
          contents = configurationContents;
        };
        sign-template = stable.pkgs.writeShellApplication {
          name = "sign-template";
          runtimeEnv.QUBES_NIXOS_RPM_CONFIG = "${stable.pkgs.rpm}/lib/rpm";
          runtimeInputs = with stable.pkgs; [
            coreutils
            rpm
            gnupg
          ];
          text = builtins.readFile ./scripts/sign-template.sh;
        };
        boot-test-image = image stable;
        boot-test-image-unstable = image unstable;
        core-test-image = image core;
        desktop-test-image = image desktop;
        desktop-test-rpm = import ./lib/template-rpm.nix {
          inherit (stable) pkgs;
          image = desktop-test-image;
          name = "nixos-26.05-desktop-test";
          appmenus = [
            "firefox.desktop"
            "xfce4-terminal.desktop"
            "thunar.desktop"
          ];
        };
        core-test-rpm = import ./lib/template-rpm.nix {
          inherit (stable) pkgs;
          image = core-test-image;
          name = "nixos-26.05-core-test";
        };
        boot-test-rpm = import ./lib/template-rpm.nix {
          inherit (stable) pkgs;
          image = boot-test-image;
          name = "nixos-26.05-boot-test";
        };
        boot-test-rpm-unstable = import ./lib/template-rpm.nix {
          inherit (stable) pkgs;
          image = boot-test-image-unstable;
          name = "nixos-unstable-boot-test";
        };
      };

      apps.${system}.sign-template = {
        type = "app";
        program = "${self.packages.${system}.sign-template}/bin/sign-template";
        meta.description = "Sign a built Qubes template RPM outside the Nix store";
      };

      checks.${system} = {
        template-rpm = import ./tests/template-rpm.nix { inherit (stable) pkgs; };

        path-adaptations =
          stable.pkgs.runCommand "qubes-path-adaptation-tests"
            {
              nativeBuildInputs = [ stable.pkgs.python3 ];
            }
            ''
              python3 ${./tests/test_paths.py} ${./pkgs/relocate-paths.py}
              touch "$out"
            '';

        signing =
          stable.pkgs.runCommand "qubes-template-signing-tests"
            {
              nativeBuildInputs = with stable.pkgs; [
                python3
                rpm
                gnupg
              ];
            }
            ''
              python3 ${./tests/test_signing.py} \
                ${self.packages.${system}.sign-template}/bin/sign-template \
                ${stable.pkgs.rpm}/lib/rpm
              touch "$out"
            '';

        profiles = import ./tests/profiles.nix {
          inherit (stable) pkgs;
          full = [
            template
            templateUnstable
          ];
          minimal = [
            minimal
            minimalUnstable
          ];
        };
      };

      devShells.${system}.release = stable.pkgs.mkShell {
        packages = with stable.pkgs; [
          createrepo_c
          gh
          gnupg
          rpm
        ];
      };

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-tree;
    };
}
