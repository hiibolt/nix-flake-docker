# Using Nix Flakes with Docker and Caching Nix Store

This repository demonstrates how to integrate Nix Flakes with Docker for building and running applications, while efficiently caching dependencies to optimize build times.

## Dockerfile

The `Dockerfile` is designed to build and package your application using Nix Flakes within a Docker container. Here's a breakdown of its key components:

```dockerfile
FROM nixos/nix:2.18.3 AS builder

# Update Nix channels and enable experimental features for flakes
RUN nix-channel --update
RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

# Set the working directory for the application
WORKDIR /app

# Copy necessary files for the Nix Flake
COPY flake.nix flake.lock Cargo.lock ./

# Cache dependencies using Nix
RUN nix develop .#nix-flake-docker

# Copy the entire application source code
COPY . .

# Build the application using the Nix Flake
RUN nix build .#nix-flake-docker

# Specify the command to run the built binary
CMD ["/app/result/bin/nix-flake-docker"]
```

### Explanation:
- **Base Image (`FROM nixos/nix:2.18.3 AS builder`)**: Starts from the official NixOS base image, version 2.18.3, which includes the Nix package manager.
  
- **Updating Nix Channels**: Ensures that the Nix channels are up to date to fetch the latest packages and dependencies.

- **Enabling Flakes**: Flakes are a new feature in Nix that allows declarative and reproducible package definitions. This line enables flakes as an experimental feature in Nix.

- **Setting Up Environment (`WORKDIR /app`)**: Defines `/app` as the working directory where the application will be built and run inside the Docker container.

- **Copying Flake Files**: Copies `flake.nix`, `flake.lock`, and `Cargo.lock` into the Docker image. These files define the Nix Flake and its dependencies.

- **Caching Dependencies (`RUN nix develop .#nix-flake-docker`)**: Utilizes `nix develop` to fetch and cache dependencies specified in `flake.nix` to speed up subsequent builds.

- **Copying Application Code**: Copies the entire local application codebase into the Docker image, allowing the build process to access and compile the application.

- **Building the Application (`RUN nix build .#nix-flake-docker`)**: Executes `nix build` to compile the application defined by the Nix Flake (`nix-flake-docker`).

- **Running the Application (`CMD ["/app/result/bin/nix-flake-docker"]`)**: Specifies the default command to run when a container is started from this image. Adjust this command according to how your application is structured.

## GitHub Actions Workflow (`main.yml`)

The GitHub Actions workflow defined in `.github/workflows/main.yml` automates the build and publish process of the Docker image whenever changes are pushed to the `master` branch.

```yaml
name: Build and Publish Docker Image

on:
  push:
    branches:
      - master

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build-and-push-image:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Log in to the Container registry
        uses: docker/login-action@65b78e6e13532edd9afa3aa52ac7964289d1a9c1
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - uses: nixbuild/nix-quick-install-action@v27

      - name: Restore and cache Nix store
        uses: nix-community/cache-nix-action@v5
        with:
          primary-key: nix-${{ runner.os }}-${{ hashFiles('**/*.nix') }}
          restore-prefixes-first-match: nix-${{ runner.os }}-
          gc-max-store-size-linux: 1073741824
          purge: true
          purge-prefixes: cache-${{ runner.os }}-
          purge-created: 0
          purge-primary-key: never
      
      - name: Extract metadata for Docker
        id: meta
        uses: docker/metadata-action@9ec57ed1fcdbf14dcef7dfbe97b2010124a938b7
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
      
      - name: Build and push Docker image
        uses: docker/build-push-action@f2a1d5e99d037542a71f64918e516c093c6f3fc4
        with:
          context: .
          push: true
          tags: ghcr.io/${{ github.repository }}:latest
          labels: ${{ steps.meta.outputs.labels }}
```

### Workflow Explanation:
- **Trigger (`on: push: branches: ['master']`)**: The workflow runs on every push to the `master` branch, initiating the build process.

- **Authentication**: `docker/login-action` is used to authenticate with GitHub Container Registry using the `GITHUB_TOKEN` provided by GitHub Actions.

- **Caching Nix Store**: `cache-nix-action` optimizes build times by caching the Nix store between workflow runs. This action ensures that dependencies fetched by Nix are stored and reused across builds.

- **Metadata Extraction**: `metadata-action` extracts tags and labels for the Docker image from metadata defined within the repository, ensuring consistency and versioning.

- **Building and Pushing Docker Image**: `build-push-action` builds the Docker image using the Dockerfile in the repository's root directory (`context: .`) and pushes it to GitHub Container Registry (`ghcr.io/${{ github.repository }}`).

## Credits
Many, many people from the Nix community have helped me, as it's a lot of intricate systems between Nix, the Nix store, Docker, Rust, Cargo, and GitHub CI/CD.

Too many to list, which is a testament to how amazing the Nix community is. I've never met so many people so willing to help someone so obviously noobish (me), it's a great corner of the internet.
