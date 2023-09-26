{ buildEnv, config, date, dockerTools, lib, linkFarm, stdenvNoCC, writeText,

# Basic system packages
bashInteractive, cacert, coreutils, git, nix, pathsFromGraph, perl, shadow
, stdenv }:

let
  passwd = writeText "passwd" ''
    root:x:0:0::/root:/run/current-system/sw/bin/bash
    ${builtins.concatStringsSep "\n" (lib.genList (i:
      "nixbld${toString (i + 1)}:x:${
        toString (i + 30001)
      }:30000::/var/empty:/run/current-system/sw/bin/nologin") 32)}
  '';

  group = writeText "group" ''
    root:x:0:
    nixbld:x:30000:${
      builtins.concatStringsSep ","
      (lib.genList (i: "nixbld${toString (i + 1)}") 32)
    }
    nogroup:x:65534:
  '';

  system = stdenvNoCC.mkDerivation {
    name = "bootstrap-base-image-system";
    phases = [ "installPhase" "fixupPhase" ];

    exportReferencesGraph = map (drv: [ ("closure-" + baseNameOf drv) drv ]) [
      cacert
      config.system.build.etc
      config.system.path
    ];

    installPhase = ''
      mkdir -p $out/bin $out/usr/bin
      ln -s ${stdenv.shell} $out/bin/sh
      ln -s ${coreutils}/bin/env $out/usr/bin/env

      cp -r ${config.system.build.etc}/etc/ $out/etc/
      chmod 755 $out/etc

      # Podman writes over these.
      rm $out/etc/{hostname,hosts}

      cp ${passwd} $out/etc/passwd
      cp ${group} $out/etc/group

      mkdir -p $out/var/empty

      printRegistration=1 ${perl}/bin/perl ${pathsFromGraph} closure-* > $out/.reginfo
    '';
  };

  stage1 = dockerTools.buildImage {
    name = "bootstrap-base-image-stage1";
    tag = date;
    created = "now";
    copyToRoot = system;
    config = {
      Cmd = [ "${bashInteractive}/bin/bash" ];
      Env = [
        "MANPATH=/run/current-system/sw/share/man"
        "NIX_SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt"
        "PATH=/run/current-system/sw/bin"
      ];
    };
  };

  dockerfile = writeText "Dockerfile-stage2" ''
    FROM bootstrap-base-image-stage1:${date}

    RUN ${coreutils}/bin/mkdir -p /run/current-system /var \
     && ${coreutils}/bin/ln -s ${config.system.path} /run/current-system/sw
    RUN nix-store --init \
     && nix-store --load-db < .reginfo \
     && mkdir /root \
     && mkdir -m 1777 /tmp \
     && ln -s /run /var/run \
     && ln -s ${config.system.path} /nix/var/nix/gcroots/booted-system \
     && ln -s ${config.system.build.etc} /nix/var/nix/gcroots/etc \
     && nix-store --gc
  '';

in linkFarm "bootstrap-files" [
  {
    name = "stage1.tar.gz";
    path = stage1;
  }
  {
    name = "Dockerfile-stage2";
    path = dockerfile;
  }
]
