#!/usr/bin/env bash
# verify_image.sh - sanity checks for the fabric-newsletter Docker image.
# Usage: ./verify_image.sh [image:tag]     (default: fabric-newsletter:lazy)
#
# Checks:
#   1. Image size
#   2. Model cache contains t5-small and does NOT contain distilbart
#   3. t5-small loads with network access disabled (proves it is baked in)
#   4. distilbart cannot load offline (proves it is lazy-loaded, not baked in)
#   5. Kaleido can export a PNG chart
#   6. Application source compiles

set -uo pipefail

IMAGE="${1:-fabric-newsletter:lazy}"
FAILED=0

pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILED=1; }

run_py() {
  docker run --rm -e HF_HUB_OFFLINE=1 -e TRANSFORMERS_OFFLINE=1 \
    --entrypoint python "$IMAGE" -c "$1"
}

echo "Image under test: $IMAGE"
echo

echo "1. Image size"
docker images --format '  {{.Repository}}:{{.Tag}}  disk={{.Size}}  content={{.ID}}' "$IMAGE"
docker images "$IMAGE"
echo "  Note: compare the CONTENT SIZE column with the ECR size (compressed)."
echo

echo "2. Model cache contents"
CACHE="$(docker run --rm --entrypoint sh "$IMAGE" -c 'ls /opt/hf/hub 2>/dev/null')"
echo "$CACHE" | sed 's/^/  /'
echo "$CACHE" | grep -q 't5-small'   && pass "t5-small is present"      || fail "t5-small is missing"
echo "$CACHE" | grep -q 'distilbart' && fail "distilbart is still baked in" || pass "distilbart is not baked in"
echo

echo "3. t5-small loads offline"
if run_py "
from transformers import AutoTokenizer, AutoModelForSeq2SeqLM
AutoTokenizer.from_pretrained('t5-small')
AutoModelForSeq2SeqLM.from_pretrained('t5-small')
print('ok')
" >/dev/null 2>&1; then
  pass "t5-small loaded without network"
else
  fail "t5-small failed to load offline"
fi
echo

echo "4. distilbart is lazy (must fail offline)"
if run_py "
from transformers import AutoModelForSeq2SeqLM
AutoModelForSeq2SeqLM.from_pretrained('sshleifer/distilbart-cnn-12-6')
" >/dev/null 2>&1; then
  fail "distilbart loaded offline, so it is still in the image"
else
  pass "distilbart is not available offline (expected)"
fi
echo

echo "5. Kaleido chart export"
if docker run --rm --entrypoint python "$IMAGE" -c "
import plotly.express as px
px.bar(x=[1,2], y=[3,4]).write_image('/tmp/t.png')
print('ok')
" >/dev/null 2>&1; then
  pass "PNG export works"
else
  fail "Kaleido export failed"
fi
echo

echo "6. Application source compiles"
if docker run --rm --entrypoint python "$IMAGE" -m py_compile /app/src/events.py /app/src/main.py; then
  pass "events.py and main.py compile"
else
  fail "compile error in application source"
fi
echo

if [ "$FAILED" -eq 0 ]; then
  echo "RESULT: all checks passed"
else
  echo "RESULT: one or more checks failed"
  exit 1
fi
