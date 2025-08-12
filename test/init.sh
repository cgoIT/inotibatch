#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Starting inotibatch with config test..."
exec /inotibatch/bin/inotibatch.sh test

echo "✅ InotiBatch is running."

# Prevent container from exiting
tail -f /dev/null