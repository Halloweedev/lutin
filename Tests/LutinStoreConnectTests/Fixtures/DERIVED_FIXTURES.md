# Fixture provenance

- `apps-view.json`, `versions-list.json`, `plan.json`, `approved.json`,
  `review-status.json` are **derived**: transcribed from asc 5.3.0's own Go
  structs (github.com/rorkai/App-Store-Connect-CLI, tag `5.3.0`,
  `internal/asc/` and `internal/cli/metadata/review.go`). They encode the
  contract, not a recording. Run `ASC_APP_ID=… ./scripts/record-asc-fixtures.sh`
  to replace them with real output; the diff is the review.
- Everything else in this directory is recorded from the real binary; see
  `RECORDED_WITH`.
