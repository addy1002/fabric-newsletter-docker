# syntax=docker/dockerfile:1

# =====================================================================
# Stage 1: builder
# Installs Python packages and downloads the models and nltk data.
# Only /opt/venv, /opt/hf and /opt/nltk_data are copied to the final image,
# so pip, build leftovers and download caches never reach production.
# =====================================================================
FROM python:3.11-slim-bookworm AS builder

# Fixed paths for the model cache (HF_HOME) and nltk data (NLTK_DATA),
# so they can be copied cleanly into the runtime stage.
ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    HF_HOME=/opt/hf \
    NLTK_DATA=/opt/nltk_data

# Virtual environment: a single folder to copy into the runtime stage.
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install CPU-only torch first, which avoids the much larger CUDA wheels.
# requirements.txt lists plain "torch", so pip treats it as already satisfied.
RUN pip install torch --index-url https://download.pytorch.org/whl/cpu

# Copy requirements.txt before the application code, so this layer stays
# cached until the dependencies change.
# kaleido is pinned to 0.2.1 in the same install, so it is installed once.
COPY requirements.txt .
RUN pip install -r requirements.txt kaleido==0.2.1

# Download models and nltk data before copying the application code,
# so code changes do not trigger a new model download.
# Only t5-small is baked into the image. distilbart is a fallback model and
# is loaded on demand at runtime (see get_distilbart() in src/events.py).
COPY load_models_in_image.py .
RUN python load_models_in_image.py \
 && python -c "import nltk; nltk.download('punkt', download_dir='/opt/nltk_data')"


# =====================================================================
# Stage 2: runtime (this is the image that gets pushed to ECR)
# =====================================================================
FROM python:3.11-slim-bookworm AS runtime

# System libraries required by Kaleido's bundled Chromium (chart PNG export).
# libgtk-3-0 pulls in most of the remaining GTK and X11 dependencies.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgtk-3-0 \
    libnss3 \
    libxss1 \
    libasound2 \
    fonts-liberation \
 && rm -rf /var/lib/apt/lists/*

# Copy only the build results from the builder stage.
COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /opt/hf /opt/hf
COPY --from=builder /opt/nltk_data /opt/nltk_data

ENV PATH="/opt/venv/bin:$PATH" \
    HF_HOME=/opt/hf \
    NLTK_DATA=/opt/nltk_data \
    PLOTLY_RENDERER=kaleido \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Application code last, because it changes most often.
# .dockerignore keeps notebooks, html-dev and other unused files out.
COPY . .

ENTRYPOINT ["python", "src/main.py"]
