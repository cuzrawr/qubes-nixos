{ pkgs }:
let
  sources = import ./sources.nix { inherit (pkgs) lib fetchFromGitHub; };
in
rec {
  libvchan = pkgs.callPackage ./libvchan.nix { upstream = sources.libvchan; };
  qubesdb = pkgs.callPackage ./qubesdb.nix {
    inherit libvchan;
    upstream = sources.qubesdb;
  };
  qrexec = pkgs.callPackage ./qrexec.nix {
    inherit libvchan;
    upstream = sources.qrexec;
  };
  linux-utils = pkgs.callPackage ./linux-utils.nix {
    inherit qubesdb;
    upstream = sources.linux-utils;
  };
  core-agent = pkgs.callPackage ./core-agent.nix {
    inherit qubesdb qrexec linux-utils;
    upstream = sources.core-agent;
  };
  update-vm = pkgs.callPackage ./update-vm.nix {
    inherit qrexec core-agent;
    upstream = sources.core-agent;
  };
  gui-common = pkgs.callPackage ./gui-common.nix { upstream = sources.gui-common; };
  gui-agent = pkgs.callPackage ./gui-agent.nix {
    inherit
      libvchan
      qubesdb
      qrexec
      core-agent
      gui-common
      ;
    upstream = sources.gui-agent;
  };
  usb-proxy = pkgs.callPackage ./usb-proxy.nix {
    inherit qubesdb qrexec;
    upstream = sources.usb-proxy;
  };
  input-proxy = pkgs.callPackage ./input-proxy.nix {
    inherit qrexec;
    upstream = sources.input-proxy;
  };
  pdf-converter = pkgs.callPackage ./pdf-converter.nix {
    inherit qrexec core-agent;
    upstream = sources.pdf-converter;
  };
  img-converter = pkgs.callPackage ./img-converter.nix {
    inherit qrexec linux-utils core-agent;
    upstream = sources.img-converter;
  };
  notification-proxy = pkgs.callPackage ./notification-proxy.nix {
    inherit qrexec linux-utils;
    upstream = sources.notification-proxy;
  };
  split-gpg2 = pkgs.callPackage ./split-gpg2.nix {
    inherit qrexec;
    upstream = sources.split-gpg2;
  };
}
