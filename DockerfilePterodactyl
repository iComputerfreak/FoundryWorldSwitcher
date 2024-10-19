# ================================
# Build image
# ================================
FROM swift:6.0-jammy as build

MAINTAINER Jonas Frey, <dev@jonasfrey.de>

# Install OS updates
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y\
    && rm -rf /var/lib/apt/lists/*

# Set up a build area
WORKDIR /build

# First just resolve dependencies.
# This creates a cached layer that can be reused
# as long as your Package.swift/Package.resolved
# files do not change.
COPY ./Package.* ./
RUN swift package resolve --skip-update \
        $([ -f ./Package.resolved ] && echo "--force-resolved-versions" || true)

# Copy the remaining code into the container now
# We don't copy everything, so we can re-use this layer even if a non-source file in the root folder changes
COPY ./Sources ./

# Build everything, with optimizations
RUN swift build -c release --static-swift-stdlib

# Switch to the staging area
WORKDIR /staging

# Copy main executable to the staging area
RUN cp "$(swift build --package-path /build -c release --show-bin-path)/FoundryWorldSwitcher" ./

# Copy resources bundled by SPM to the staging area
RUN find -L "$(swift build --package-path /build -c release --show-bin-path)/" -regex '.*\.resources$' -exec cp -Ra {} ./ \;

# ================================
# Run image
# ================================
FROM swift:6.0-jammy-slim

# Make sure all system packages are up to date, and install only essential packages.
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get -q install -y \
      ca-certificates \
      tzdata \
# If your app or its dependencies import FoundationNetworking, also install `libcurl4`.
      libcurl4 \
# If your app or its dependencies import FoundationXML, also install `libxml2`.
      # libxml2 \
    && rm -r /var/lib/apt/lists/*

# Create a container user with /home/container as its home directory
RUN adduser --disabled-password --home /home/container container

# Use the container user from now on
USER container
ENV USER=container HOME=/home/container

# Switch to the new home directory
WORKDIR /home/container

# Copy built executable and any staged resources from builder
COPY --from=build --chown=container:container /staging /home/container

# Provide configuration needed by the built-in crash reporter and some sensible default behaviors.
ENV SWIFT_ROOT=/usr SWIFT_BACKTRACE=enable=yes,sanitize=yes,threads=all,images=all,interactive=no

# Ensure all further commands run as the container user
USER container:container

# Create a new data directory
RUN mkdir -p /home/container/data

# Start the bot
COPY ./entrypoint.sh /entrypoint.sh
CMD ["/bin/bash", "/entrypoint.sh"]
