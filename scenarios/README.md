# Test scenarios

Run these after the GitHub setup in the main README is done. Each one proves a part of the pipeline works. Take a screenshot of the Checks tab for each, you'll need them for the report and the dashboard.

Start every scenario from a clean `main`:

```bash
git checkout main && git pull
```

## Scenario 1: clean pull request

```bash
./scripts/run-scenario.sh 1
git push -u origin scenario-1-clean-pr
```

Open a PR into main.

**What should happen:** all four checks go green. The merge button is enabled. Nothing is deployed yet.

## Scenario 2: merge and deploy

Merge the PR from scenario 1.

**What should happen:** go to Actions → CD. The checks run again, the image is pushed to GitHub Container Registry, and staging is deployed and smoke tested. Production then waits with a "Review deployments" button. Approve it and production deploys.

## Scenario 3: leaked secret

```bash
./scripts/run-scenario.sh 3
git push -u origin scenario-3-leaked-secret
```

This adds `src/config.js` with a fake AWS key written directly in the code.

**What should happen:** `Secret scan (Gitleaks)` fails and the PR cannot be merged. The job log shows the file and line.

**Clean up:** close the PR and delete the branch. Don't just add a commit that removes the key, Gitleaks will still find it in the earlier commit. That's the real lesson here: once a secret is pushed, treat it as leaked. In a real project you would revoke the key and load it from GitHub Secrets instead.

## Scenario 4: SQL injection

```bash
./scripts/run-scenario.sh 4
git push -u origin scenario-4-sql-injection
```

This rewrites the search function to join user input straight into the SQL string.

**What should happen:** `Code scan (CodeQL)` fails with a SQL injection finding (`js/sql-injection`), pointing at `src/users.js`. You'll also see it under the repo's Security tab. `Lint and test` fails too, because one test sends `' OR '1'='1` and checks it doesn't return every user.

Two gates catching it is a good point for your presentation: the test only catches it because someone wrote that test, while CodeQL catches the pattern even without one.

**Clean up:** close the PR and delete the branch.

## Scenario 5: vulnerable base image

```bash
./scripts/run-scenario.sh 5
git push -u origin scenario-5-vulnerable-image
```

This switches the runtime image to an old `node:16-bullseye` image.

**What should happen:** all code checks pass, the image builds, then `Build and scan image` fails at the Trivy step with a table of HIGH and CRITICAL vulnerabilities. The image is never pushed.

**Clean up:** close the PR and delete the branch.

## Record your results

For each scenario note down: the PR or run link, which check passed or failed, how long the run took, and a screenshot. Those go into your report and replace the planned scenarios on the dashboard.
