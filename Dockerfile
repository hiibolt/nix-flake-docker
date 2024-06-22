FROM nixos/nix:2.18.3 AS builder

# Set up the environment for Nix Flakes
RUN nix-channel --update
RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

# Set up the environment for the Nix Flake
WORKDIR /app
COPY flake.nix flake.lock Cargo.lock ./

# Cache the dependencies
RUN nix develop .#nix-flake-docker

# Import the work directory and build
COPY . .
RUN nix build .#nix-flake-docker

# Run the binary
CMD ["/app/result/bin/nix-flake-docker"]

# Reminder: Command to run this image with terminal is `docker run -it <image> /bin/bash`