# iAlly Test & Release Scripts

All scripts run from the `ios/` directory.

---

## Testing

### `run_tests.sh` — Canonical test runner (per CLAUDE.md protocol)
```bash
bash scripts/run_tests.sh build   # Clean build only
bash scripts/run_tests.sh smoke   # Build + Launch + Smoke tests
bash scripts/run_tests.sh ui      # Build + all 11 Essential UI suites
bash scripts/run_tests.sh all     # Build + smoke + full UI (default)
```

### `quick_test.sh` — Fast iteration during development
```bash
bash scripts/quick_test.sh unit   # Unit tests only
bash scripts/quick_test.sh ui     # UI tests only
bash scripts/quick_test.sh all    # All tests
```

### `cleanup_test_environment.sh` — Reset simulator environment before tests
```bash
bash scripts/cleanup_test_environment.sh
```

---

## Release

### `pre_testflight_check.sh` — Full pre-release gate
```bash
bash scripts/pre_testflight_check.sh
```
Runs: debug + release builds, unit + UI + e2e tests, code coverage, static analysis, archive validation.

### `version.sh` — Manage version & build numbers
```bash
bash scripts/version.sh get
bash scripts/version.sh patch     # 1.0.0 → 1.0.1
bash scripts/version.sh minor     # 1.0.0 → 1.1.0
bash scripts/version.sh major     # 1.0.0 → 2.0.0
```

### `changelog.sh` — Generate release notes from git commits
```bash
bash scripts/changelog.sh
```

---

## CI/CD (GitHub Actions)

### `autonomous_ci.sh` — Background CI monitor
```bash
bash scripts/autonomous_ci.sh start   # Start background polling
bash scripts/autonomous_ci.sh stop    # Stop background polling
bash scripts/autonomous_ci.sh status  # Check if running
```

### `poll_ci.sh` — Poll until all CI jobs finish
```bash
bash scripts/poll_ci.sh
```

### `ci_summary.sh` — Fetch CI run status and artifacts
```bash
bash scripts/ci_summary.sh
```

### `clean_artifacts.sh` — Remove downloaded CI artifact files
```bash
bash scripts/clean_artifacts.sh
```

---

## Dependencies

- **Xcode 16+**
- **xcpretty:** `gem install xcpretty --no-document`
- **iPhone 17 Simulator / iOS 26.1**

---

**Last Updated:** March 2026
