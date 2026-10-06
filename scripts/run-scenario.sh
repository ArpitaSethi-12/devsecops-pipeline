#!/usr/bin/env bash
# Sets up one of the five test scenarios on a new branch.
# Usage: ./scripts/run-scenario.sh 1|3|4|5
# (Scenario 2 is just merging scenario 1, see scenarios/README.md)
set -euo pipefail

n="${1:-}"
cd "$(git rev-parse --show-toplevel)"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Commit or stash your changes first."; exit 1
fi
git checkout main && git pull --ff-only

case "$n" in
  1)
    branch="scenario-1-clean-pr"
    git checkout -b "$branch"
    cat >> src/app.js <<'JS'

// Scenario 1: a small, safe change
app.get('/api/ping', (req, res) => res.json({ pong: true }));
JS
    # keep module.exports as the last line
    node -e "
      const fs=require('fs');let s=fs.readFileSync('src/app.js','utf8');
      s=s.replace('module.exports = app;\n','')+'\nmodule.exports = app;\n';
      fs.writeFileSync('src/app.js',s);"
    git commit -am "Add ping endpoint"
    ;;
  3)
    branch="scenario-3-leaked-secret"
    git checkout -b "$branch"
    # Builds a fake key at runtime so this script itself does not trip Gitleaks
    rand() { node -e "const c=process.argv[1];let o='';for(const b of require('crypto').randomBytes(+process.argv[2]))o+=c[b%c.length];console.log(o)" "$1" "$2"; }
    key="AKIA$(rand ABCDEFGHIJKLMNOPQRSTUVWXYZ234567 16)"
    secret="$(rand ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 40)"
    cat > src/config.js <<JS
// Scenario 3: a fake AWS key written directly in code
module.exports = {
  aws: {
    region: 'ap-south-1',
    accessKeyId: '${key}',
    secretAccessKey: '${secret}',
  },
};
JS
    git add src/config.js
    git commit -m "Add S3 config"
    ;;
  4)
    branch="scenario-4-sql-injection"
    git checkout -b "$branch"
    node -e "
      const fs=require('fs');let s=fs.readFileSync('src/users.js','utf8');
      const safe=/async function searchUsers[\s\S]*?\n}\n/;
      const unsafe=\`async function searchUsers(name) {
  // Scenario 4: UNSAFE, user input is joined straight into the SQL string
  const { rows } = await pool.query(
    \"SELECT id, name, email FROM users WHERE name ILIKE '%\" + name + \"%' ORDER BY id\",
  );
  return rows;
}
\`;
      if(!safe.test(s)) { console.error('searchUsers not found'); process.exit(1); }
      fs.writeFileSync('src/users.js', s.replace(safe, unsafe));"
    git commit -am "Simplify search query"
    ;;
  5)
    branch="scenario-5-vulnerable-image"
    git checkout -b "$branch"
    # Swap the runtime base for an old Node 16 image with known vulnerabilities
    sed -i.bak \
      -e 's/^FROM node:22-alpine AS runtime/FROM node:16-bullseye AS runtime/' \
      -e '/^RUN apk upgrade/d' \
      -e '/^# Patch OS packages/d' Dockerfile && rm -f Dockerfile.bak
    git commit -am "Switch runtime to node 16 image"
    ;;
  *)
    echo "Usage: $0 1|3|4|5"; exit 1 ;;
esac

echo
echo "Branch $branch is ready. Now run:"
echo "  git push -u origin $branch"
echo "Then open a pull request into main on GitHub and watch the checks."
