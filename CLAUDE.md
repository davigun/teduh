# Koinonia — Flutter Bible app (Indonesian, Supabase backend)

## Run
- Simulator: `xcrun simctl boot B535929D-B73F-4FF4-9174-C1E7AF05A4F5` (iPhone 17; UDID changes after Xcode/runtime updates — verify with `xcrun simctl list devices available`), then:
  `flutter run -d B535929D-B73F-4FF4-9174-C1E7AF05A4F5 --dart-define-from-file=env.json > /tmp/koinonia_run.log 2>&1 &`
- Kill stale runs first: `pkill -f "flutter run"`. Poll the log file for build/runtime status.
- Screenshot: `xcrun simctl io 5D2415E6-C172-493C-9899-6671A4942DC8 screenshot /tmp/shot.png`
- Physical iPhone over wifi: `flutter devices` to find it, same `flutter run -d <id> --dart-define-from-file=env.json`.
- Dart-defines only apply on fresh launch, not hot reload.

## Verify
- `flutter analyze` and `flutter test` (must pass before commit/push; pre-push hook enforces).

## Secrets
- Supabase creds in `env.json` — never print/cat it. It is gitignored. Setup SQL: `docs/SUPABASE_SETUP.md`.

## Git
- Conventional commits: `type: description` (feat/fix/refactor/docs/test/chore/perf/ci). No attribution footer.
- Commit/push only when asked. Pushes go to main. (No remote configured yet.)
