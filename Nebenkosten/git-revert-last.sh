#!/bin/bash
# Script: Letzten Commit rückgängig machen und pushen
# Aufruf: ./git-revert-last.sh
# Wichtig: Erstellt einen neuen Commit, der die Änderungen des letzten Commits rückgängig macht

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$GIT_ROOT" || exit 1

echo "=== Letzten Commit rückgängig machen (git revert HEAD) ==="
git revert HEAD --no-edit

echo ""
echo "=== Git Push ==="
git push

echo ""
echo "=== Git Status ==="
git status
