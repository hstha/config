# Use minimal Ubuntu base image
FROM ubuntu:20.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies including Git
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    software-properties-common \
    ca-certificates \
    curl \
    gnupg \
    unzip \
    lsb-release \
    git

# Install Python 3.12
RUN add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    python3.12 \
    python3.12-venv \
    python3.12-dev && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1

# Install Node.js (LTS)
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get install -y --no-install-recommends nodejs

# Install OpenJDK 21
RUN apt-get install -y --no-install-recommends openjdk-21-jdk

# Install Bun
RUN curl -fsSL https://bun.sh/install | bash
ENV BUN_INSTALL="/root/.bun"
ENV PATH="$BUN_INSTALL/bin:$PATH"

# Install Angular CLI
RUN npm install -g @angular/cli

# Install .NET SDK (LTS version)
RUN curl -sSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin --channel LTS
ENV DOTNET_ROOT="/root/.dotnet"
ENV PATH="$DOTNET_ROOT:$PATH"

# Verify installations
RUN python3 --version && \
    node -v && \
    npm -v && \
    java -version && \
    bun --version && \
    ng version && \
    dotnet --version && \
    git --version

# Set working directory
WORKDIR /app

# Default command
CMD ["bash"]
