# Mini Checklist para crear un release en GitHub

## Antes del tag

1. Verifica que `VERSION` tenga la version correcta, por ejemplo `0.1.0`.
2. Confirma que todos los cambios necesarios ya estan en `main` o en la rama que vas a etiquetar.
3. Haz `git status` y comprueba que no queden cambios sin commit.
4. Haz `git push` y espera a que GitHub Actions termine correctamente.

## Confirmar el workflow

5. Revisa que los jobs pasen en GitHub Actions:
   * `unit_tests`
   * `build_linux`
   * `test_linux`
   * `build_windows`
   * `test_windows`
   * `build_macos`
   * `test_macos`
6. Confirma que el workflow Linux ya este configurado para incluir en release:
   * `LucioIVACalculator`
   * `LucioIVACalculator.desktop`
   * `app-icon.svg`

## Crear el tag

7. Crea el tag con prefijo `v` usando la misma version de `VERSION`:

```bash
git tag v0.1.0
```

8. Sube el tag a GitHub:

```bash
git push origin v0.1.0
```

## Despues del tag

9. Espera a que se ejecute de nuevo GitHub Actions con el tag.
10. Verifica que corra el job `release`.
11. Abre la seccion Releases del repositorio y confirma que se haya creado la release.

## Revisar los assets del release

12. Comprueba que la release incluya:
   * `LucioIVACalculator-<version>-setup.exe`
   * `LucioIVACalculator`
   * `LucioIVACalculator.desktop`
   * `app-icon.svg`
   * `LucioIVACalculator-<version>-macOS-x64.zip`

## Si algo falla

13. Si el workflow del tag falla, corrige el problema, haz commit y push.
14. Borra el tag local y remoto solo si necesitas recrearlo:

```bash
git tag -d v0.1.0
git push origin :refs/tags/v0.1.0
```

15. Luego vuelve a crear y subir el tag correcto.
