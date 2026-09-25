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
- **Vidéos en local** : `php artisan serve` ne gère ni les requêtes `Range` (exigées par le lecteur iOS) ni plusieurs
  requêtes à la fois. Servir `backend/public` avec un serveur de fichiers compatible `Range` sur le port 8001 et lancer
  l'API avec `APP_URL=http://127.0.0.1:8001 PHP_CLI_SERVER_WORKERS=4 php artisan serve` (en production : nginx / Wasabi).
  Envois de vidéo en local : relever `upload_max_filesize` / `post_max_size` du PHP local (2 Mo par défaut) et lancer
  `php artisan queue:work` avec `FFMPEG_PATH` / `FFPROBE_PATH` pour la vérification et l'optimisation.
- **Temps réel en local** : `node realtime/server.js` (backend) et l'API lancée avec `REALTIME_URL=http://127.0.0.1:6001`.
- Tests : `flutter test` ; parcours réels sur simulateur (`login_flow`, `feed_flow`, `like_flow`, `artist_flow` : inscription, paiement, parcours, envoi réel ; `jury_flow` : notation de la présélection, juré de démo `0100000002` / `12345678` ; `realtime_flow` : refus reçu en direct, déclenché depuis le backend ; `battles_flow` : duel, poule, vote par appui long ; aide commune `integration_test/helpers.dart`) : `flutter test integration_test -d <simulateur>
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
| Accueil | Onglets « Battles » (votes ouverts, `GET /live` : duel VS en deux moitiés, poule en grille, vote par appui long `HoldToVote`) et « Pour toi » (le fil) ; étiquette de compétition sur chaque vidéo |
| Fil | `FeedController` (curseur, copie locale, likes optimistes via la file) + `VideoPool` (≤ 4 lecteurs, lecture depuis le disque, préchargement en Wi-Fi) |
| Médias | `MediaCache` : vidéos et miniatures sur disque par identifiant **avec l'extension** (iOS l'exige), 500 Mo, les plus anciennes effacées |
| Envois | `UploadCenter` (background_downloader) : copie dans l'espace de l'app, envoi multipart confié au système (continue app fermée, reprend après une coupure), refus 4xx affichés sans nouvelle tentative |
| Jury | Thème clair (`JuryScope`) ; notes par critère (curseur + −/+), définitives en présélection, modifiables en match jusqu'à la fin de la délibération ; notes hors ligne gardées (`PendingScores`) et envoyées par la file |
| Temps réel | `RealtimeClient` (Socket.IO, jeton de `GET /realtime`, `forceNew`, jeton renouvelé) → `ActivityHub` : rechargements groupés, historique Activité (Drift), bandeau app ouverte, notification app en arrière-plan ; `LiveChannel` pour les compétitions consultées |
| Notifications | `LocalNotifier` (locales, pas de push) ; rappels programmés depuis « Mon parcours » (`ReminderScheduler` : envoi 24 h / 1 h avant, vote 1 h avant), à un instant UTC absolu |
| Réglages | Préchargement des vidéos (Wi-Fi seulement / toujours / jamais), espace du cache et « Libérer », version (`--dart-define=APP_VERSION`) |
| Session | `SessionController` : profil en cache au démarrage, jeton dans le coffre (Keychain / Keystore) |
| Navigation | go_router : onglets `StatefulShellRoute`, redirections (mot de passe provisoire, jury) |

## Design

- **Une seule source pour la marque** : `core/theme/brand.dart` (violet du site). Les écrans lisent
  `context.colors` (`AppColors.light` par défaut, `AppColors.dark` au choix dans Réglages : Clair / Sombre / Système).
  Le **fil vidéo reste toujours sombre** (`DarkFeed`), barre du bas comprise sur l'Accueil.
- **Icônes Phosphor** (MIT) : seulement Regular et Fill embarqués (`assets/fonts`), codes dans `core/theme/app_icons.dart`
  — ne pas ajouter le paquet `phosphor_flutter`, qui embarque ses 6 styles (+2 Mo).
- Ton sobre : pas d'emoji ni de points d'exclamation dans les textes (app et messages du serveur) ; logo typographique.
- Sora (titres) et Inter (texte), sous-ensembles latins embarqués (292 Ko, fonctionnent hors ligne).
- **Pas de dégradés** (règle du propriétaire) : voiles unis sur les vidéos. Contrastes ≥ 4,5:1 vérifiés.
- Guide de design : skill `ui-ux-pro-max` (`.claude/skills/`).
- Pays affichés par leur code (« CI ») : les drapeaux emoji ne s'affichent pas partout.
- **Accessibilité** : `test/features/layout_stress_test.dart` rend les écrans clés sur un petit téléphone (320 pt) avec
  le texte à 200 % — tout débordement fait échouer le test ; « Réduire les animations » respecté (`context.motion()`,
  `context.reduceMotion`) ; avatars décoratifs pour les lecteurs d'écran (le nom est toujours visible à côté).
- Chargements : squelettes unis qui pulsent (`Skeleton`, `SkeletonList`), jamais de dégradé animé.
- Portrait uniquement (fil vertical).

## Versions minimales

Android 7 (API 24), **iOS 14** (exigé par l'envoi en arrière-plan ; validé par le propriétaire).

## À retirer avant la publication

`NSAllowsArbitraryLoads` (iOS) et `usesCleartextTraffic` (Android) n'existent que pour le serveur de test en
HTTP : à supprimer dès que l'API a un domaine en HTTPS.
