FROM ubuntu:22.04

LABEL maintainer="Armin Marth"
LABEL description="Comprehensive file organization and deduplication tool with multiple modes"
LABEL version="2.0.0"

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    coreutils \
    libimage-exiftool-perl \
    file \
    tar \
    gzip \
    bzip2 \
    xz-utils \
    unzip \
    p7zip-full \
    && rm -rf /var/lib/apt/lists/*

# Create directories
RUN mkdir -p /input /output

# Copy script and make it executable
COPY organize_and_dedup.sh /usr/local/bin/organize_and_dedup.sh
RUN chmod +x /usr/local/bin/organize_and_dedup.sh

# Set working directory
WORKDIR /input

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/organize_and_dedup.sh"]

# Default command shows help
CMD ["--help"]
