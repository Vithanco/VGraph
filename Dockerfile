# syntax=docker/dockerfile:1

# Stage 1: Build vgraph-mcp-http
FROM swift:6.3 AS swift-builder

# Static stdlib link needs libc++ archives, which aren't in the base image.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libc++-dev libc++abi-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY Package.swift Package.resolved ./
COPY Sources/ Sources/
COPY Tests/ Tests/

# No `--mount=type=cache` here, deliberately. It needs BuildKit, and neither
# builder that matters has it: Cloud Build's default step is the legacy builder,
# and a plain colima + docker CLI setup has no buildx either. It also bought
# nothing on Cloud Build — a fresh worker each run means the cache is always
# cold. What it saved locally was the dependency *fetch* (~30s), not the compile;
# Docker's own layer cache still covers the common case where Sources/ is
# unchanged. Keeping the Dockerfile buildable by the classic builder is worth
# more than that.
RUN swift build -c release --product vgraph-mcp-http --static-swift-stdlib \
    && strip .build/release/vgraph-mcp-http \
    && cp .build/release/vgraph-mcp-http /app/vgraph-mcp-http-bin

# Runtime — ubuntu:24.04 matches swift:6.3's glibc (2.38).
# Only install the libs Swift Foundation dlopen's at runtime.
FROM ubuntu:24.04

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       libcurl4t64 \
       librsvg2-bin \
       libc++1 \
       libc++abi1 \
       fontconfig \
       fonts-liberation \
    && rm -rf /var/lib/apt/lists/*

# Our SVGs name three font families and this image had none of them. Verified
# by rendering a concept map in `ubuntu:24.04` + librsvg2-bin: `fc-match
# "DM Sans"` answered `DejaVuSans.ttf`, and the resulting PNG was pixel-identical
# to what mcp.vithanco.com returns. Text rendered, so nothing looked broken —
# but DejaVu is wider than what the engine measured, and a diagram's title
# overran into the logo watermark.
#
# Two families, two fixes:
#
#  - Node and relation labels ask for DM Sans, which is ours to ship. Same faces
#    the other renderers bundle; see fonts/README.md.
#  - The graph title asks for bare `Helvetica` and the watermark for bare
#    `Arial` (Attributes.Group.fontname defaults to .helvetica, not to
#    FontFamily.default). Neither exists here, and no amount of DM Sans helps.
#    fonts-liberation supplies metric-compatible substitutes, which is what
#    fixes the title/logo collision.
#
# `fontconfig` is for `fc-cache`: librsvg2-bin pulls in libfontconfig1, the
# library, not the binary. Fontconfig would scan /usr/share/fonts at first use
# anyway; building the cache at image-build time keeps that cost off a Cloud Run
# cold start.
COPY fonts/*.ttf /usr/share/fonts/truetype/dmsans/
COPY fonts/OFL.txt /usr/share/fonts/truetype/dmsans/
RUN fc-cache -f

COPY --from=swift-builder /app/vgraph-mcp-http-bin /app/vgraph-mcp-http

EXPOSE 8080

# The binary defaults to warn as well; this makes the intent visible. At debug the
# Graphviz source of every render, titles and labels included, reaches Cloud Logging.
ENV VGRAPH_LOG_LEVEL=warn

# Cloud Run sets $PORT (defaults to 8080); the server reads it from the environment
ENTRYPOINT ["/app/vgraph-mcp-http"]
