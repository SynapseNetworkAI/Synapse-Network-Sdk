# SDK Package Release Runbook

- Status: Production
- Last verified against code: 2026-05-01

This runbook covers SynapseNetwork SDK package publishing. SDKs are **published** to language registries; they are not deployed to staging or production runtime environments.

## Release Model

- `release_train_version` is the human-facing SDK train, for example `1.0.0`.
- `package_version` is the actual language package version.
- New trains initialize all package versions to the train version.
- A single language can hotfix forward, for example train `1.0.0` with Python package `1.0.1`.
- Published package versions are immutable. Do not overwrite or republish the same version; publish a higher patch version instead.
- SDK examples default to `environment="prod"` or omit the environment because prod is the SDK default. Package release channels are registry channels, not Gateway environments.

## Package Platforms

| Language | Package | Registry | Publish notes |
| --- | --- | --- | --- |
| Python | `synapse-network-ai-sdk` | PyPI | Optional TestPyPI dry-run before public release. |
| TypeScript | `@synapse-network-ai/sdk` | npm | Use npm dist-tags such as `preview`, `next`, or `latest`. |
| Go | `github.com/SynapseNetworkAI/Synapse-Network-Sdk/go` | Go module via GitHub | Because the module is in `/go`, tags must use `go/vX.Y.Z`. |
| Java | `ai.synapse-network:synapse-network-sdk` | Maven Central | Public `1.0.0` is published on Maven Central. |
| .NET | `SynapseNetwork.Sdk` | NuGet.org | Use NuGet package versions and never overwrite an existing version. |
| All | GitHub Release | GitHub | One release page per train with links to all language packages. |

The npm organization is `synapse-network-ai`: https://www.npmjs.com/org/synapse-network-ai.
Do not publish or document packages under the occupied legacy npm scope.

## Preflight

Run the full SDK quality gate:

```bash
bash scripts/ci/pr_checks.sh
```

Build/package checks:

```bash
python -m build python
python -m twine check python/dist/*

cd typescript
npm ci
npm run build
npm pack

cd ../go
go test ./...
go list ./...

cd ../java
mvn -B package

cd ../dotnet
dotnet test tests/SynapseNetwork.Sdk.Tests/SynapseNetwork.Sdk.Tests.csproj
dotnet pack src/SynapseNetwork.Sdk/SynapseNetwork.Sdk.csproj -c Release
```

## Local Runner Publishing

Use Growing `/releases?tab=sdk-packages` for controlled package publishing.
Each platform/version is one release-history row. Dry-run first, then publish
with the Human Gate confirmation phrase `PUBLISH_SDK_<version>`.

Run the worker locally after creating a dry-run or publish request:

```bash
PYTHONPATH=. /Users/cliff/workspace/agent/.venv/bin/python \
  <growing-repo>/run_sdk_publish_worker.py --once --release-id <package_release_id>
```

## Registry Secrets

Registry credentials must stay in the local runner environment or equivalent
secret storage. Do not store them in repo files, release metadata, or runner
logs.

- `PYPI_API_TOKEN`
- `NPM_TOKEN`
- `NUGET_API_KEY`
- Maven Central credentials
- GPG signing secrets if Maven Central requires signing

## Go Tag Rule

The Go module lives in a subdirectory:

```text
go/go.mod -> module github.com/SynapseNetworkAI/Synapse-Network-Sdk/go
```

Therefore Go package publishing uses subdirectory tags:

```bash
git tag go/v1.0.0
git push origin go/v1.0.0
```

Do not rely on a root `v1.0.0` tag for the Go module.

## Growing Release Center

Use `http://localhost:9700/releases` -> `SDK Packages`.

Recommended flow:

1. Click `Initialize Release Train`.
2. Enter train version, channel, release notes, and selected packages.
3. Run `Dry Run` for each package.
4. Publish packages after dry-runs pass.
5. Sync statuses until every package is `published` or explicitly `failed`.
6. Create or update the GitHub Release with package URLs.

## Post-Publish Verification

Verify install and one minimal staging invocation per language where practical:

- Install package from the public registry.
- Search for a free or smoke service.
- Invoke with an Agent Key.
- Fetch receipt.
- Confirm docs link back to the published version.

## Rollback Policy

SDK registries generally do not support safe rollback by overwriting a version. If a published package is bad:

1. Mark the package release failed or superseded in the release center notes.
2. Publish a higher patch version.
3. Update GitHub Release notes and docs with the fixed version.
