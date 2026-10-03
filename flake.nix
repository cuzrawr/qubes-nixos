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
        source:
        source.lib.nixosSystem {
          inherit system;
          modules = [
            self.nixosModules.qubes
            ./configuration.nix
            {
              # Retain the pinned nixpkgs source for local evaluation after install.
              nix.registry.nixpkgs.flake = source;
              nix.nixPath = [ "nixpkgs=${source}" ];
            }
          ];
        };
      template = mkTemplateSystem nixpkgs;
      desktopAppmenus = [
        "firefox.desktop"
        "xfce4-terminal.desktop"
        "thunar.desktop"
        "org.xfce.mousepad.desktop"
      ];
      templateUnstable = (mkTemplateSystem nixpkgs-unstable).extendModules {
        modules = [
          (
            { lib, ... }:
            {
              services.qubes.updates.configuration = lib.mkDefault "nixos-unstable";
              services.qubes.updates.inputs = lib.mkDefault [ "nixpkgs-unstable" ];
            }
          )
        ];
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
      # A writable copy, not an /etc symlink into the immutable store. The same
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
            name,
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
      };

      packages.${system} = (import ./pkgs { pkgs = stable.pkgs; }) // rec {
        default = template-rpm;
        template-rpm = self.lib.mkTemplate {
          configuration = template;
          name = "nixos-26.05-xfce";
          contents = configurationContents;
          appmenus = desktopAppmenus;
        };
        template-rpm-unstable = self.lib.mkTemplate {
          configuration = templateUnstable;
          name = "nixos-unstable-xfce";
          contents = configurationContents;
          appmenus = desktopAppmenus;
        };
        sign-template = stable.pkgs.writeShellApplication {
          name = "sign-template";
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

      checks.${system}.path-adaptations =
        stable.pkgs.runCommand "qubes-path-adaptation-tests"
          {
            nativeBuildInputs = [ stable.pkgs.python3 ];
          }
          ''
            python3 ${./tests/test_paths.py} ${./pkgs/relocate-paths.py}
            touch "$out"
          '';

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
