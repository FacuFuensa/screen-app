# Screen

Tiempo en pantalla de a dos: cada uno limita sus apps y el otro aprueba los minutos extra.

- Spec: `docs/superpowers/specs/2026-10-12-screen-design.md`
- Plan: `docs/superpowers/plans/2026-10-12-screen-v1.md`
- El `.xcodeproj` se genera con XcodeGen en CI (`project.yml`); no se commitea.
- Tests: `ScreenCore` y SQL corren en GitHub Actions; `deno test supabase/functions/_shared` corre local.
