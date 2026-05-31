# Use lightweight Python base
FROM python:3.11-slim

# Install system dependencies (Java JDK for unluac.jar, curl for downloading lune)
RUN apt-get update && apt-get install -y --no-install-recommends \
    default-jre-headless \
    curl \
    ca-certificates \
    unzip \
    lua5.3 \
    && rm -rf /var/lib/apt/lists/*

# Install Lune binary
RUN curl -fsSL https://github.com/lune-org/lune/releases/download/v0.8.4/lune-0.8.4-linux-x86_64.zip -o lune.zip \
    && unzip lune.zip \
    && mv lune /usr/local/bin/lune \
    && rm lune.zip

# Set up working directory
WORKDIR /app

# Copy dependency specifications and install
COPY sift/requirements.txt requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy all source files
COPY . .

# Create required dump directories at build time
RUN mkdir -p dumps/temp dumps/original dumps/dumped

# Expose FastAPI Web Port
EXPOSE 8000

# Set environment variables
ENV HOST=0.0.0.0
ENV PORT=8000
ENV LUNE_PATH=lune
ENV JAVA_PATH=java
ENV UNLUAC_JAR_PATH=/app/deobfuscate/unluac.jar

# Run both the web backend and the Discord bot
CMD ["python", "-m", "sift.main"]
