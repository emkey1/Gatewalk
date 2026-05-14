# Validation Checks

Run deterministic generation and save migration checks:

```bash
"/Users/mke/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --script res://tools/validation/run_checks.gd
```

Expected result:
- Exit code `0`
- Output contains: `VALIDATION OK: deterministic generation and save migration checks passed`

If a check fails, the script exits non-zero and prints one or more `VALIDATION FAIL:` lines.
