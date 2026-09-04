# Definition of done

A change is done when every line below is true. Say which ones do not apply and why.

- [ ] The issue's acceptance criteria are met, no more and no less.
- [ ] Tests exist for new behaviour and all tests pass locally.
- [ ] Lint, format and type checks pass.
- [ ] No new warnings were introduced.
- [ ] `CHANGELOG.md` has an entry under Unreleased if the change is user-visible.
- [ ] `docs/architecture.md` still describes the system. Update it if a module changed responsibility.
- [ ] Any decision that would be expensive to reverse has an ADR.
- [ ] New environment variables are in `.env.example` and documented.
- [ ] No secrets, credentials or personal data in the diff.
- [ ] Commit messages follow conventional commits and reference the issue.
