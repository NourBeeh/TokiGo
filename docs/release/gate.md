# 10C — Release Gate (final checklist before production)

Status: CHECKLIST CREATED.

Requirements per spec §52 / MASTER_PLAN.md 23:
- Separate dev/staging/prod environments.
- Secret manager (no .env in repo — FIXED in 9A audit).
- Restricted CORS, migrations/backups, observability.
- CI/CD pipeline.
- Privacy policy / consent records.
- Security review (P4 MASVS framework ready).
- One market (EG) + one product canary first.

Current state:
- Flutter test: 262 passed / 0 skipped / 0 failed (last full run).
- Backend tsc: clean; jest: 320 passed.
- .env gitignored.
- Real provider data only (Nuitee).
- Sandbox booking only (ACC_CREDIT_CARD simulated).
- No production environment configured.
- No CI/CD pipeline configured.

Do NOT release (10C) until all above completed and verified on device.
