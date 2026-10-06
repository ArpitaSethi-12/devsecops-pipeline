# DevSecOps pipeline for a Node.js API

A small users API with a CI/CD pipeline on GitHub Actions. Every change goes through tests and four security checks before it can be merged or deployed. If any check fails, the code is blocked.

## How the pipeline works

```
Pull request ──► Code checks ──────────────► Build image ──► Trivy scan     (stops here on PRs)
                 • Lint and tests
                 • Gitleaks (secrets)
                 • CodeQL (code security)

Merge to main ─► same checks ─► build ─► scan ─► push to GHCR ─► deploy staging ─► approve ─► deploy production
```

- **On a pull request** (`ci.yml`): checks, build and scan run. Nothing is pushed or deployed. Branch protection stops the merge if anything fails.
- **On merge to main** (`cd.yml`): the same checks run again, the image is pushed to GitHub Container Registry, then deployed to staging. Production waits for your approval.
- **Deploy** (`deploy.yml`): applies the Kubernetes files and runs a smoke test that checks `/health` returns the new version.
- **Dependabot** checks npm packages, the Docker base image and GitHub Actions every week and opens PRs for updates.

## Folder structure

```
.github/
  workflows/
    ci.yml          checks, build and scan (runs on PRs)
    cd.yml          full pipeline after merge to main
    deploy.yml      reusable deploy job for staging and production
  dependabot.yml
src/                the API (Express + Postgres)
tests/              API tests (Node's built-in test runner)
k8s/                Kubernetes files for the API and Postgres
scripts/
  deploy.sh         deploys to a namespace
  smoke-test.sh     checks the deployed app is healthy
  run-scenario.sh   sets up the test scenarios
scenarios/          step by step guide for the 5 test scenarios
docs/dashboard.html project dashboard for presentations
Dockerfile          multi-stage, non-root, no npm in the final image
docker-compose.yml  run everything locally
```

## API

| Method | Path | What it does |
|---|---|---|
| GET | `/health` | Health check with app version |
| GET | `/api/users` | List users |
| GET | `/api/users/:id` | Get one user |
| GET | `/api/users/search?name=` | Search users by name |
| POST | `/api/users` | Create a user (`{ "name": "...", "email": "..." }`) |

## Run it locally

You need Node 22 and Docker.

```bash
npm install
docker compose up --build
```

The API is now at http://localhost:3000. Try it:

```bash
curl -X POST localhost:3000/api/users -H 'content-type: application/json' -d '{"name":"Asha","email":"asha@example.com"}'
curl localhost:3000/api/users
```

To run the tests, start only the database and run them from your machine:

```bash
docker compose up -d db
npm run lint
npm test
```

## Set it up on GitHub

### Quick way: one script

Install the [GitHub CLI](https://cli.github.com), log in, and run the setup script from the project folder:

```bash
gh auth login
./scripts/setup-github.sh
```

It creates a public repo, the `staging` and `production` environments (production needs your approval), turns on Dependabot alerts, pushes the code and protects `main`. Then skip to the scenarios.

### Manual way

1. **Create a public repo** and push this code to `main`. Public matters: CodeQL results upload is free only on public repos.

2. **Let the first run finish.** Go to the Actions tab. The CD workflow runs on the first push. This also creates the check names you need in the next step.

3. **Protect the main branch.** Settings → Branches → Add branch protection rule for `main`:
   - Require a pull request before merging
   - Require status checks to pass, and add these four:
     `Lint and test`, `Secret scan (Gitleaks)`, `Code scan (CodeQL)`, `Build and scan image`
   - Do not allow bypassing the above settings

4. **Create two environments.** Settings → Environments:
   - `staging`, no rules
   - `production`, turn on **Required reviewers** and add yourself. This is the manual approval step.

5. **Turn on Dependabot alerts.** Settings → Code security → enable Dependabot alerts and security updates.

That's it. Open a PR and you'll see the checks run.

### Where does it deploy?

By default the deploy job creates a **temporary Kubernetes cluster (kind) inside the GitHub runner**, deploys the app and Postgres, runs the smoke test, and then the runner is thrown away. This costs nothing and proves the whole deploy works.

To deploy to a real cluster instead (for example k3s on a cloud VM), add these secrets to the `staging` and `production` environments:

| Secret | Value |
|---|---|
| `KUBE_CONFIG` | Your kubeconfig, base64 encoded: `base64 -w0 ~/.kube/config` |
| `DB_PASSWORD` | Optional. A password for Postgres. If missing, one is generated on first deploy. |

For a real cluster, also make the image public: on your GitHub profile go to Packages → this package → Package settings → Change visibility. The cluster API server must be reachable from the internet for GitHub-hosted runners. If the smoke test fails on a real cluster, the job rolls back to the previous version automatically.

## Run the 5 test scenarios

These prove each security gate actually works. Full steps are in [scenarios/README.md](scenarios/README.md).

| # | Scenario | Expected result |
|---|---|---|
| 1 | Clean pull request | All checks pass, PR can be merged |
| 2 | Merge to main | Image pushed, deployed to staging, then production after approval |
| 3 | Leaked AWS key | Gitleaks blocks the PR |
| 4 | SQL injection | CodeQL (and a test) block the PR |
| 5 | Vulnerable base image | Trivy blocks the PR |

## Security choices in this project

- Secrets come from GitHub Secrets and Kubernetes Secrets, never from code.
- SQL queries always use parameters (`$1`), never string joining.
- Each workflow job gets only the permissions it needs.
- The container runs as a non-root user with a read-only filesystem and no Linux capabilities.
- npm, yarn and corepack are removed from the final image since the app does not need them at runtime.
- Images are tagged with the commit SHA, so you can always trace a deployment back to its exact code.
- Production needs a human approval.
