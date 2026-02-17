#!/bin/bash
# Script: Alle Änderungen committen und pushen
# Aufruf: ./git-commit-push.sh "Deine Commit-Nachricht"
# Beispiel: ./git-commit-push.sh "Zählerdaten-Layout verbessert"

if [ -z "$1" ]; then
    echo "Bitte Commit-Nachricht angeben:"
    echo "  ./git-commit-push.sh \"Deine Nachricht\""
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$GIT_ROOT" || exit 1

echo "=== Git Add ==="
git add .

echo ""
echo "=== Git Status (vor Commit) ==="
git status

echo ""
echo "=== Git Commit ==="
git commit -m "Whng. plus Eingabe"

echo ""
echo "=== Git Push ==="
git push

echo ""
echo "=== Git Status (nach Push) ==="
git status
