#!/usr/bin/env bash
# One-time GitHub setup: creates the repo, environments, Dependabot alerts and branch protection.
# Run from the project folder after logging in with: gh auth login
# Usage: ./scripts/setup-github.sh [repo-name]
set -euo pipefail
NAME="${1:-devsecops-pipeline}"

command -v gh >/dev/null || { echo "Install the GitHub CLI first: https://cli.github.com"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "Log in first: gh auth login"; exit 1; }

if [ ! -d .git ]; then
  git init -b main
  git add -A
  git commit -m "Initial commit"
fi

echo "Creating public repo $NAME"
gh repo create "$NAME" --public --source=. --remote=origin
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
USER_ID=$(gh api user -q .id)

# Environments are created before the first push so production asks for approval from the very first run
echo "Creating staging and production environments"
gh api -X PUT "repos/$REPO/environments/staging" >/dev/null
gh api -X PUT "repos/$REPO/environments/production" --input - >/dev/null <<JSON
{"reviewers":[{"type":"User","id":$USER_ID}]}
JSON

echo "Turning on Dependabot alerts and security updates"
gh api -X PUT "repos/$REPO/vulnerability-alerts" >/dev/null
gh api -X PUT "repos/$REPO/automated-security-fixes" >/dev/null

echo "Pushing code"
git push -u origin main

echo "Protecting the main branch"
gh api -X PUT "repos/$REPO/branches/main/protection" --input - >/dev/null <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["Lint and test", "Secret scan (Gitleaks)", "Code scan (CodeQL)", "Build and scan image"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": { "required_approving_review_count": 0 },
  "restrictions": null
}
JSON

echo
echo "Done. Your repo: https://github.com/$REPO"
echo "The first pipeline run has started: https://github.com/$REPO/actions"
echo "When it reaches production, open the run and click 'Review deployments' to approve."
