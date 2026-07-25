args@{ my, ... }:
# The tracer-bullet guest: the thinnest complete path from discovery to a
# running nested container. Its interior is just the guest-base — the baseline
# toolset and SSH access — so it proves the concept without carrying a service.
my.guest { name = "sample"; } args
