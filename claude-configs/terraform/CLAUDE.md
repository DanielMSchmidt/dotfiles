# Terraform

## Building & Testing

- `go build ./...` — build all packages
- `go test ./internal/<pkg>/...` — run tests for a specific package
- `go test -run TestName ./internal/<pkg>/...` — run a single test
- `go test -race ./internal/terraform ./internal/command ./internal/states` — race detection (CI runs this)
- `TF_ACC=1 go test -v ./internal/command/e2etest` — end-to-end acceptance tests
- `make generate` — regenerate dynamic source files (run after non-protobuf changes)
- `make protobuf` — regenerate protobuf stubs (requires protoc)

## Code Quality Checks (CI runs all of these)

- `make fmtcheck` — verify `go fmt` compliance
- `make importscheck` — verify import ordering (`goimports`)
- `make vetcheck` — run `go vet`
- `make staticcheck` — run staticcheck linter
- `make exhaustive` — check exhaustive switch statements
- `make copyright` — verify copyright headers

## Code Style

- Use `go fmt` formatting (enforced by CI)
- Use `goimports` for import ordering (enforced by CI)
- Follow existing patterns in each package
- Copyright header required on all `.go` files:
  ```
  // Copyright IBM Corp. 2014, 2026
  // SPDX-License-Identifier: BUSL-1.1
  ```

## Project Structure

- `internal/command/` — CLI commands (each implements a `Command` interface via `hashicorp/cli`)
- `internal/terraform/` — core Terraform engine
- `internal/configs/` — configuration loading and parsing (HCL)
- `internal/states/` — state management
- `internal/plans/` — plan file handling
- `internal/providers/` — provider integration
- `internal/backend/` — state backend implementations
- `internal/addrs/` — address types for Terraform resources
- `internal/lang/` — language features and expression evaluation
- `internal/cloud/` — HCP Terraform/Cloud integrations
- `internal/rpcapi/` — RPC API implementations
- `internal/plugin/`, `internal/plugin6/` — provider plugin protocols
- `internal/dag/` — directed acyclic graph implementation
- `scripts/` — build and CI scripts
- `tools/` — development tooling (protobuf compiler, etc.)

## Testing Patterns

- Standard Go `testing` package with `t.Run()` table-driven tests
- `google/go-cmp` for deep comparisons
- Test fixtures in `testdata/` directories within each package
- Common helpers: `t.TempDir()`, `t.Chdir()`, `testFixturePath()`, `testCopyDir()`
- Command tests use `testView()` and `metaOverridesForProvider()` for test provider setup

## Files to Never Edit Directly

- `*.pb.go` — generated protobuf stubs (use `make protobuf`)
- `go.sum` — generated dependency lock file (use `make syncdeps`)
- Files under `testdata/` that are auto-generated

## License

BUSL-1.1 (Business Source License). All new `.go` files need the copyright header.
