#!/usr/bin/env bash
# One-shot script to create the taurist-ai repo under Taurist-Technologies
# and enable GitHub Pages. Idempotent: safe to re-run.
set -euo pipefail

ORG="Taurist-Technologies"
REPO="taurist-ai"
BRANCH="main"

# Always run from the directory this script lives in (the repo root).
cd "$(dirname "$0")"

echo "==> Working dir: $(pwd)"

# ---- 1. Sanity-check tools ----
command -v git >/dev/null || { echo "git not found"; exit 1; }
command -v gh  >/dev/null || { echo "gh CLI not found. Install: brew install gh"; exit 1; }

# ---- 2. Confirm gh auth ----
if ! gh auth status >/dev/null 2>&1; then
  echo "==> gh is not authenticated. Running: gh auth login"
  gh auth login
fi

# Make sure we have repo + workflow scopes (workflow is harmless to request)
gh auth refresh -h github.com -s repo,workflow >/dev/null 2>&1 || true

# ---- 3. Clean up junk files that shouldn't be committed ----
find . -name ".DS_Store" -delete 2>/dev/null || true
# The .gitignore already excludes landing-page.html; remove the local copy too
# so the folder is clean (index.html is the canonical version).
[ -f landing-page.html ] && rm -f landing-page.html

# ---- 4. Initialize git repo if needed ----
if [ ! -d .git ]; then
  echo "==> git init"
  git init -b "$BRANCH"
fi

# ---- 5. Stage + commit ----
git add -A
if git diff --cached --quiet; then
  echo "==> Nothing new to commit."
else
  git -c user.email="rhillx.code@gmail.com" \
      -c user.name="RHILLX" \
      commit -m "Initial commit: Taurist AI landing page"
fi

# ---- 6. Create the remote repo on the org if it doesn't exist ----
if gh repo view "$ORG/$REPO" >/dev/null 2>&1; then
  echo "==> Repo $ORG/$REPO already exists, skipping create."
else
  echo "==> Creating $ORG/$REPO (public)"
  gh repo create "$ORG/$REPO" --public --description "Taurist AI services landing page" --homepage "https://taurist-technologies.github.io/$REPO/"
fi

# ---- 7. Wire up the remote + push ----
if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "https://github.com/$ORG/$REPO.git"
else
  git remote add origin "https://github.com/$ORG/$REPO.git"
fi

git branch -M "$BRANCH"
git push -u origin "$BRANCH"

# ---- 8. Enable GitHub Pages (main / root) ----
echo "==> Enabling GitHub Pages on $BRANCH / root"
if gh api "repos/$ORG/$REPO/pages" >/dev/null 2>&1; then
  echo "==> Pages already enabled, updating source to $BRANCH/root"
  gh api -X PUT "repos/$ORG/$REPO/pages" \
    -f "source[branch]=$BRANCH" -f "source[path]=/" >/dev/null
else
  gh api -X POST "repos/$ORG/$REPO/pages" \
    -f "source[branch]=$BRANCH" -f "source[path]=/" >/dev/null
fi

# ---- 9. Wait briefly + show final URL ----
sleep 3
PAGES_URL="$(gh api "repos/$ORG/$REPO/pages" --jq .html_url 2>/dev/null || echo "https://taurist-technologies.github.io/$REPO/")"

echo ""
echo "================================================================"
echo "  Done."
echo "  Repo:  https://github.com/$ORG/$REPO"
echo "  Site:  $PAGES_URL"
echo "  Note:  first deploy can take ~30-90s. Refresh if 404."
echo "================================================================"
