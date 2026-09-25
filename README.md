# Battle Game — app mobile

App Flutter des **fans, artistes et jurés** de Battle Game (le back-office organisateur reste sur le web).
Une seule app : univers sombre façon TikTok pour le public et les artistes, **espace jury** clair et
épuré pour les comptes jurés.

## Démarrer

```bash
flutter pub get
dart run build_runner build --force-jit      # code Drift (après un changement de tables)
flutter run --dart-define=API_URL=http://127.0.0.1:8000   # backend local (php artisan serve)
```

- `API_URL` : racine du backend, sans `/api` (défaut : le serveur de test `http://185.215.167.87:8081`).
- `START` (développement) : écran d'ouverture, ex. `--dart-define=START=/auth/connexion`.
- Tests : `flutter test` ; parcours réel sur simulateur : `flutter test integration_test -d <simulateur>
  --dart-define=API_URL=http://127.0.0.1:8000` (compte artiste de démo `0799000001` / `12345678`).
- Version de production Android : `flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols`.

## Architecture

```
lib/
  core/        config · theme (marque, jetons, couleurs, icônes) · network · storage · offline · router · widgets
  features/    auth · shell (onglets) · jury · … (data/ puis presentation/)
```

| Sujet | Choix |
|---|---|
| État | Riverpod (`core/providers.dart` = racine de composition, surchargeable en test) |
| Réseau | Dio via `ApiClient` : jeton, `X-Device-Id`, erreurs traduites en français (`ApiException`) |
| Cache | `HttpCacheInterceptor` : chaque GET est gardé en base avec son ETag ; `304` = copie locale |
| Affichage | `watchResource()` : copie locale immédiate, puis réponse du serveur (même hors ligne) |
| Hors ligne | `Outbox` : écritures en file, envoyées dans l'ordre avec `Idempotency-Key`, reprise progressive |
| Base locale | Drift (SQLite) : cache HTTP, file d'actions, valeurs (profil, appareil) |
| Session | `SessionController` : profil en cache au démarrage, jeton dans le coffre (Keychain / Keystore) |
| Navigation | go_router : onglets `StatefulShellRoute`, redirections (mot de passe provisoire, jury) |

## Design

- **Une seule source pour la marque** : `core/theme/brand.dart` (violet du site). Les écrans lisent
  `context.colors` (`AppColors.fan` sombre, `AppColors.jury` clair) ; icônes dans `core/theme/app_icons.dart`.
- Sora (titres) et Inter (texte), sous-ensembles latins embarqués (292 Ko, fonctionnent hors ligne).
- **Pas de dégradés** (règle du propriétaire) : voiles unis sur les vidéos. Contrastes ≥ 4,5:1 vérifiés.
- Guide de design : skill `ui-ux-pro-max` (`.claude/skills/`).
- Pays affichés par leur code (« CI ») : les drapeaux emoji ne s'affichent pas partout.

## À retirer avant la publication

`NSAllowsArbitraryLoads` (iOS) et `usesCleartextTraffic` (Android) n'existent que pour le serveur de test en
HTTP : à supprimer dès que l'API a un domaine en HTTPS.
