{ lib, fetchFromGitHub }:
lib.mapAttrs
  (
    _: source:
    source
    // {
      src = fetchFromGitHub {
        owner = "QubesOS";
        inherit (source) repo hash;
        rev = source.rev or "v${source.version}";
      };
    }
  )
  {
    libvchan = {
      repo = "qubes-core-vchan-xen";
      version = "4.2.8";
      hash = "sha256-8pwVGYhaHTcvSHlF2wS+XyiHon8q5tmO72YDnoyfZVk=";
    };
    qubesdb = {
      repo = "qubes-core-qubesdb";
      version = "4.3.3";
      hash = "sha256-KKuEt+X3L4H3HVAkJru9fxKa05xuxlcex+uQWPpBPVw=";
    };
    qrexec = {
      repo = "qubes-core-qrexec";
      version = "4.3.15";
      hash = "sha256-DrgJFtPb1YHieDffs3RD24hjxcX347eZlaZNO/3/MXk=";
    };
    core-agent = {
      repo = "qubes-core-agent-linux";
      version = "4.3.48";
      hash = "sha256-g8WjsPvGHgLYCCXWpqXKZpUt8AJkDZi7WrYo37t/ers=";
    };
    gui-common = {
      repo = "qubes-gui-common";
      version = "4.3.1";
      hash = "sha256-RDB2tS+vLXu7RwA6Ng4TekIubzIKtuQK8ALRGjsXmcY=";
    };
    gui-agent = {
      repo = "qubes-gui-agent-linux";
      version = "4.3.21";
      hash = "sha256-XQcoN/xod32bd0SlasiC5+SQt/WgbDQvrCmPmUKswJc=";
    };
    linux-utils = {
      repo = "qubes-linux-utils";
      version = "4.3.19";
      hash = "sha256-GWo/AxETIDBsDMvn18zhz44cBLj6Xrdn/rdLnsTT+u8=";
    };
    usb-proxy = {
      repo = "qubes-app-linux-usb-proxy";
      version = "4.3.5";
      hash = "sha256-ieN+GtDmlL4cARnFcM3dVsjNKeH1ZuXUElTj2Tu3H+w=";
    };
    input-proxy = {
      repo = "qubes-app-linux-input-proxy";
      version = "1.0.46";
      hash = "sha256-4yfdBcdAlahKnV76htdOojWgordZyM0H7JfvXzn8owE=";
    };
    pdf-converter = {
      repo = "qubes-app-linux-pdf-converter";
      version = "2.1.26";
      hash = "sha256-Yqc7PIXlsR7413TGOaEd4U3m9wkAjQ27F0Qq3ClWrQ8=";
    };
    img-converter = {
      repo = "qubes-app-linux-img-converter";
      version = "1.2.19";
      hash = "sha256-7kDX/nM3OnriEu78JB5erx1fsBx7VPPzqQHq3l0+zhQ=";
    };
    notification-proxy = {
      repo = "qubes-notification-proxy";
      version = "1.0.10";
      hash = "sha256-A8F60q6tXpcKrjHuJ0wAPOc/dHeVA/LZHv2Cj28ZwLU=";
    };
    split-gpg2 = {
      repo = "qubes-app-linux-split-gpg2";
      version = "1.1.14";
      hash = "sha256-6t1E/1NbilUPlGKl8kqgeK1tqcAeXSXt159C6EPqSi0=";
    };
    template-builder = {
      repo = "qubes-builderv2";
      version = "2026-09-27";
      rev = "d5d57ab7ef0535c205d6e7b5b8771790a8c3cce8";
      hash = "sha256-n+9hYE+UV4udyQCziPpWnOT8fmQnRIDbqSHuqbZ9F7w=";
    };
  }
