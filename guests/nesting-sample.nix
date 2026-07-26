args@{ my, ... }:
# A sample guest whose interior runs an OCI container on Podman.
# The image is pulled at runtime, so the guest builds with no build-time fetch.
my.guest {
  name = "nesting-sample";
  interior = {
    virtualisation.oci-containers.containers.hello = {
      image = "docker.io/library/hello-world";
    };
  };
} args
