# Developer & Contributor Guide — sagani.nvim

Welcome! This guide outlines development protocols, testing procedures, and contribution workflows for **sagani.nvim**.

---

## 🧪 Headless Testing Protocol

All code changes MUST be verified using the zero-dependency headless unit test runner:

```bash
nvim --headless -u NONE -c "luafile tests/run_tests.lua"
```

### Test Suite Modules (`tests/`)

- `tests/run_tests.lua`: Master test runner executing all sub-suites.
- `tests/test_backend.lua`: Backend auto-detection, registry, and task routing tests.
- `tests/test_opencode_protocol.lua`: HTTP ACP server lifecycle, reasoning part filtering, and multi-turn sessions.
- `tests/test_selection.lua`: Characterwise (`v`), linewise (`V`), and blockwise (`<C-v>`) selection extraction.
- `tests/test_diff.lua`: Diff hunk calculation, baseline snapshotting, and hunk acceptance/rejection.
- `tests/test_acp.lua`: Floating markdown popup UI and single-keypress Pin Mode tests.

---

## 🛠️ Contribution Workflow

1. **Fork & Branch**: Create a feature branch (`feature/my-addition` or `fix/issue-name`).
2. **Implement & Test**: Add code changes and accompanying unit tests under `tests/`.
3. **Verify Pass Rate**: Run `nvim --headless -u NONE -c "luafile tests/run_tests.lua"` and verify 100% test pass rate.
4. **Submit PR**: Open a Pull Request on GitHub describing changes and test results.
