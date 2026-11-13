# fabric-newsletter Docker image (multi-stage)

Multi-stage Dockerfile for the fabric-newsletter service.

- Builder stage installs packages and downloads models; runtime stage copies only the results.
- Models are downloaded before the code copy, so code changes do not re-download them.
- distilbart (1.2 GB) is a fallback model and is loaded only when needed.

Compressed size (amd64): about 1.74 GB (old, ECR) to about 0.72 GB (new).

Note: application code (src/) is not included here, so this repo is for review only.
