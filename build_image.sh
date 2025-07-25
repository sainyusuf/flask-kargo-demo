#!/bin/bash
set -e

RELEASE_VERSION="${RELEASE_VERSION:="latest-$GH_BUILD_NUMBER"}"
ECR_URL="${ECR_URL:=}"
APPLICATION_NAME="${APPLICATION_NAME:=}"
PROJECT_IDENTIFIER="${PROJECT_IDENTIFIER:=}"
#PLATFORMS="linux/arm64"
PLATFORMS="linux/amd64"

BUILDER_NAME="multiarch-builder" # Consistent builder name across all builds

if [[ -z $APPLICATION_NAME ]]; then
  echo "expected env APPLICATION_NAME to be set but was empty"
  exit 1
fi

if [[ -z $PROJECT_IDENTIFIER ]]; then
  echo "expected env PROJECT_IDENTIFIER to be set but was empty"
  exit 1
fi

if [[ -z $ECR_URL ]]; then
  echo "expected env ECR_URL to be set but was empty"
  exit 1
fi

imageTagWithVersion="$ECR_URL:$RELEASE_VERSION"

echo "Image tag is '$imageTagWithVersion'"

# 1. Check Docker Buildx
if ! command -v docker buildx &>/dev/null; then
  echo "Error: docker buildx is not installed. Please install Docker Buildx."
  exit 1
fi

# 2. Set up QEMU (for non-native builds)
#    This is often needed on x86_64 GitHub Actions runners to build ARM64 images.
if [[ "$(uname -m)" != "aarch64" ]]; then
  echo "Setting up QEMU for multi-architecture build..."
  docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
fi

echo "building container image..."

# 3. Create and Use a Buildx Builder with docker-container driver
if ! docker buildx ls | grep -q "$BUILDER_NAME"; then
  echo "Creating Docker Buildx builder '$BUILDER_NAME'..."
  docker buildx create --name "$BUILDER_NAME" --driver docker-container --use
else
  echo "Using existing Docker Buildx builder '$BUILDER_NAME'..."
  docker buildx use "$BUILDER_NAME"
fi

# 4. Build and Push the Multi-Architecture Image
echo "Building multi-platform image for: $PLATFORMS"
docker buildx build --platform "$PLATFORMS" -t $imageTagWithVersion --push .

echo "pushing container image to '$imageTagWithVersion'..."
#docker push $imageTagWithVersion