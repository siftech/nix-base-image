#!/bin/sh
set -eux



# The tag of the nixos/nix image we use for building the base image.
alpine_nix_tag=2.13.1

# Today's date, used as a tag.
date="$(date +"%Y-%m-%d")"

# The name of the image to create.
image="ghcr.io/siftech/nix-base-image:$date"



build_script="
nix-build /code/bootstrap.nix --argstr date $date -o /tmp/result
cp -L /tmp/result/stage1.tar.gz /code/stage1.tar.gz
cp -L /tmp/result/Dockerfile-stage2 /code/Dockerfile-stage2
chmod 644 /code/stage1.tar.gz /code/Dockerfile-stage2
"

docker pull "nixos/nix:$alpine_nix_tag"
docker run --rm -v "$(pwd):/code" "nixos/nix:$alpine_nix_tag" bash -c "$build_script"
docker load <stage1.tar.gz
rm stage1.tar.gz
docker build -t "$image" -f Dockerfile-stage2 .
rm Dockerfile-stage2

docker push "$image"

docker tag "$image" ghcr.io/siftech/nix-base-image:latest
docker push ghcr.io/siftech/nix-base-image:latest
