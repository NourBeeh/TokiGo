#!/bin/sh

set -e

ROOT="$(git rev-parse --show-toplevel)"
MEMORY="$ROOT/PROJECT_MEMORY"

echo "======================================"
echo " TokiGo AI Handoff"
echo "======================================"
echo

echo "MASTER MEMORY:"
echo "$MEMORY/01_MASTER_MEMORY.md"
echo

echo "CURRENT STATE:"
echo "$MEMORY/03_CURRENT_STATE.md"
echo

echo "PHASE HISTORY:"
echo "$MEMORY/04_PHASE_HISTORY.md"
echo

echo "ARCHITECTURE:"
echo "$MEMORY/05_ARCHITECTURE.md"
echo

echo "DECISIONS:"
echo "$MEMORY/06_DECISIONS.md"
echo

echo "KNOWN ISSUES:"
echo "$MEMORY/07_KNOWN_ISSUES.md"
echo

echo "NEXT STEPS:"
echo "$MEMORY/08_NEXT_STEPS.md"
echo

echo "AI HANDOFF:"
echo "$MEMORY/09_AI_HANDOFF.md"
echo

echo "DEEPSEEK CONTEXT:"
echo "$MEMORY/10_DEEPSEEK_CONTEXT.md"
echo

echo "======================================"
echo " Recommended reading order"
echo "======================================"
echo
echo "1. 01_MASTER_MEMORY.md"
echo "2. 03_CURRENT_STATE.md"
echo "3. 09_AI_HANDOFF.md"
echo "4. 08_NEXT_STEPS.md"
echo "5. 10_DEEPSEEK_CONTEXT.md"
echo

echo "======================================"
echo " Git"
echo "======================================"
git log -5 --oneline --decorate
echo

git status --short
