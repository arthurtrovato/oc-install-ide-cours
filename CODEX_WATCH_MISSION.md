# Mission Codex — installer et valider la complication Meteoblue sur Apple Watch

## Mode d'exécution obligatoire

Tu es l'agent d'exécution local sur ce Mac. Utilise **Computer Use** pour contrôler Terminal, Finder, Xcode, Réglages système et, si disponible, iPhone Mirroring. Utilise aussi le terminal lorsque c'est plus fiable ou plus rapide.

**Ne te contente pas d'expliquer ou de donner un plan. Exécute réellement le travail.** Continue jusqu'à l'un des deux résultats suivants :

1. la complication Meteoblue est installée et validée sur l'Apple Watch ;
2. tu rencontres un blocage réellement impossible à franchir sans une action physique ou une information secrète de ma part.

Quand une intervention humaine est inévitable, demande **une seule action précise à la fois**, attends que je la fasse, puis reprends automatiquement. Ne transforme pas les étapes ordinaires en instructions pour moi si tu peux les exécuter toi-même avec Computer Use.

## Contexte de référence

- Dépôt : `arthurtrovato/oc-install-ide-cours`
- Branche de travail unique : `meteoblue-widget`
- Ne touche jamais à `master`.
- Ne touche jamais à `ProjetLedor`.
- Lis d'abord intégralement `HANDOFF.md`, puis `WATCH_INSTALL.md`.
- La dernière voie Watch préparée utilise `Scripts/prepare_watch_install.sh`.
- Le widget iPhone 1.0.3 (95.1) est installé, mais son toucher ouvre encore Safari. **Ne travaille pas sur ce problème pendant cette mission.**
- La Watch doit afficher des données meteoblue, mais toucher la complication doit volontairement ouvrir **Météo d'Apple sur l'Apple Watch**.
- Ne remets pas les bundles Watch dans l'IPA SideStore.

## Règles de sécurité et de conservation

- N'efface jamais de fichiers personnels ni de modifications locales non sauvegardées.
- Si un clone local contient des modifications suivies par Git, ne les annule pas. Utilise plutôt un nouveau clone ou un `git worktree` propre basé sur `origin/meteoblue-widget`.
- N'utilise aucune ressource cloud payante, aucun abonnement Apple Developer payant et ne publie rien sur l'App Store.
- Utilise la **Personal Team gratuite** du compte Apple déjà présent ou que je connecterai dans Xcode.
- Ne révèle, n'affiche, ne copie dans les logs et ne commit jamais : mot de passe Apple, code 2FA, mot de passe Mac, clé API meteoblue ou autre secret.
- `Config/Secrets.xcconfig` doit rester local, ignoré par Git et ne jamais entrer dans un commit.
- Ne demande ma clé meteoblue que si elle manque réellement. Utilise alors une saisie silencieuse dans Terminal et ne la répète jamais dans la conversation ou les logs.
- Pour tout écran Apple ID, mot de passe, 2FA, déverrouillage, confiance, code de l'Apple Watch ou activation du mode développeur, arrête-toi juste avant la saisie et demande-moi l'action physique exacte. Ne tente pas de lire ou mémoriser le secret.
- Les demandes d'autorisation macOS/Codex nécessaires à Terminal, Xcode, réseau ou automatisation peuvent être présentées ; explique brièvement pourquoi puis poursuis dès qu'elles sont accordées.

## Critères de réussite

La mission n'est terminée que lorsque les points suivants ont été vérifiés autant que possible :

1. Xcode reconnaît l'iPhone compagnon et l'Apple Watch comme destination.
2. `MeteoblueWatch` et `MeteoblueWatchWidgetExtension` sont signés avec la Personal Team.
3. L'app Watch est réellement installée et se lance sur la montre.
4. La demande de localisation apparaît et l'autorisation est accordée.
5. L'app Watch charge de vraies données meteoblue.
6. La complication `Meteoblue 5 h` apparaît dans un emplacement rectangulaire.
7. La complication affiche des données réelles cohérentes.
8. Toucher la complication ouvre Météo d'Apple sur la Watch.
9. `HANDOFF.md` est mis à jour avec le résultat physique exact, les erreurs, les corrections, les commits, le HEAD et les CI.
10. Toute modification de code/documentation utile est commitée et poussée sur `meteoblue-widget`, avec les CI pertinents vérifiés.

## Procédure d'exécution

### 1. Trouver ou préparer le dépôt

1. Cherche un clone local de `oc-install-ide-cours` sous le dossier utilisateur, notamment avec Spotlight/`mdfind` et les dossiers habituels (`~/Developer`, `~/Documents`, `~/Projects`).
2. Vérifie l'URL `origin` et utilise uniquement le dépôt `arthurtrovato/oc-install-ide-cours`.
3. S'il n'existe pas, clone-le dans un emplacement raisonnable, par exemple `~/Developer/oc-install-ide-cours`.
4. Si le clone est propre :
   - `git fetch origin`
   - `git switch meteoblue-widget`
   - `git pull --ff-only origin meteoblue-widget`
5. Si le clone a des modifications suivies par Git, ne les écrase pas. Crée un clone ou worktree propre séparé pour cette mission.
6. Vérifie que le HEAD correspond bien au dernier `origin/meteoblue-widget`.
7. Lis `HANDOFF.md` et `WATCH_INSTALL.md` avant toute modification.

### 2. Préparer le projet Watch

1. Exécute :

```sh
./Scripts/prepare_watch_install.sh
```

2. Si le fichier n'est pas exécutable, corrige uniquement le bit exécutable localement puis relance.
3. Si XcodeGen manque, utilise Homebrew si présent. Si Homebrew manque, demande mon accord avant d'installer Homebrew ; sinon installe XcodeGen par une méthode officielle et sûre.
4. Si Xcode demande d'accepter la licence, effectue la procédure ; demande-moi uniquement le mot de passe administrateur au moment où macOS l'exige.
5. Si `Config/Secrets.xcconfig` manque ou contient un placeholder, demande-moi de saisir la clé meteoblue dans la saisie silencieuse du script. Ne l'affiche pas.
6. Vérifie après génération que le scheme `MeteoblueWatch` existe et que le projet `MeteoblueWeather.xcodeproj` s'ouvre.

### 3. Préparer les appareils et Xcode

1. Vérifie que le Mac a le Wi-Fi et le Bluetooth actifs.
2. Vérifie que l'iPhone compagnon et l'Apple Watch sont allumés, proches, appairés, sur le même réseau Wi-Fi lorsque nécessaire et suffisamment chargés.
3. Utilise Xcode > Settings > Accounts pour vérifier qu'un compte Apple est présent.
4. Si une connexion Apple ID ou un code 2FA est demandé, demande-moi de le saisir moi-même puis reprends.
5. Ouvre Window > Devices and Simulators / Device Hub.
6. Branche l'iPhone au Mac si cela améliore l'appairage.
7. Termine l'appairage Xcode de l'iPhone et attends que l'Apple Watch apparaisse comme destination associée.
8. Si macOS, l'iPhone ou la Watch demande : confiance, code, redémarrage ou Developer Mode, demande-moi l'action physique exacte, une à la fois, puis reprends après confirmation.
9. Si la Watch n'apparaît pas, diagnostique méthodiquement : compatibilité Xcode/watchOS, appareils déverrouillés, câble, confiance, Wi-Fi/Bluetooth, Developer Mode, « Connect via network », puis redémarrage ciblé si nécessaire. Ne modifie pas le code pour un problème d'appairage.

### 4. Configurer la signature

1. Dans le projet Xcode, sélectionne la target `MeteoblueWatch`.
2. Active `Automatically manage signing` et choisis la Personal Team.
3. Répète pour `MeteoblueWatchWidgetExtension`.
4. Si Xcode exige aussi la target iPhone compagnon pour résoudre le companion bundle, configure sa Personal Team sans modifier son Bundle ID ni réintégrer la Watch dans SideStore.
5. Si un Bundle ID Watch est réellement indisponible pour cette équipe :
   - modifie uniquement les deux Bundle IDs Watch dans `project.yml` ;
   - conserve une relation cohérente où l'ID de l'extension commence par l'ID de l'app Watch ;
   - utilise un suffixe unique et stable ;
   - ne modifie pas les Bundle IDs iPhone ;
   - régénère le projet avec XcodeGen ;
   - documente précisément le changement dans `HANDOFF.md`.
6. N'effectue pas de changement de code préventif. Pars du premier message Xcode réel.

### 5. Installer sur la vraie Apple Watch

1. Sélectionne le scheme `MeteoblueWatch`.
2. Sélectionne l'Apple Watch physique comme destination.
3. Lance Run dans Xcode.
4. Sur échec :
   - récupère l'erreur exacte dans l'Issue Navigator et le Report Navigator ;
   - utilise les logs `xcodebuild`/Xcode si nécessaire ;
   - classe le problème : signature, provisioning, compatibilité, pairing, installation, lancement ou runtime ;
   - applique le correctif minimal ;
   - reconstruis et reteste.
5. Pour tout changement de code ou de configuration : exécute les tests pertinents, au minimum la génération Xcode et les builds Watch simulator + `generic/platform=watchOS`. Exécute aussi `swift test` si le changement touche le code partagé.
6. Commit et pousse les corrections sur `meteoblue-widget`, puis vérifie les CI Watch et iOS. Ne laisse pas une correction locale non documentée.

### 6. Valider sur la Watch

1. Lance l'app Meteoblue sur la Watch.
2. Si la Watch demande la localisation, demande-moi de l'autoriser sur la montre, puis poursuis.
3. Vérifie que l'app ne signale pas de clé absente et qu'elle charge des données météo réelles.
4. Ouvre la console Xcode si l'app reste vide ou affiche une erreur ; corrige la cause réelle plutôt que de masquer le message.
5. Ajoute la complication `Meteoblue 5 h` à un emplacement rectangulaire :
   - essaie d'utiliser l'app Watch sur l'iPhone via iPhone Mirroring si elle est disponible et fiable ;
   - sinon demande-moi uniquement les gestes nécessaires sur l'iPhone ou la Watch.
6. Vérifie visuellement les températures, précipitations et heures affichées.
7. Demande-moi de toucher la complication sur la Watch si cette interaction ne peut pas être automatisée, puis confirme que **Météo d'Apple** s'ouvre sur la montre.
8. Force un rechargement depuis l'app Watch si nécessaire et vérifie qu'une nouvelle timeline apparaît.

### 7. Clôturer proprement

Avant de terminer :

1. Mets à jour `HANDOFF.md` avec :
   - date/heure ;
   - chemin local utilisé ;
   - version macOS/Xcode/iOS/watchOS et modèle Watch si visibles ;
   - HEAD initial et final ;
   - fichiers modifiés ;
   - erreurs exactes ;
   - corrections ;
   - résultat physique pour l'app, la complication, la météo et le toucher ;
   - CI et leurs résultats ;
   - prochain blocage ou prochaine action s'il en reste un.
2. Vérifie `git diff` et `git status`.
3. Ne commit jamais `Config/Secrets.xcconfig`, DerivedData, archives, profils ou données sensibles.
4. Commit et pousse `HANDOFF.md` et les modifications utiles sur `meteoblue-widget`.
5. Donne-moi un compte rendu final factuel : ce qui a été réellement validé, ce qui reste incertain et la prochaine action exacte.

## Première action à exécuter maintenant

Commence immédiatement par localiser le clone, le mettre à jour sur `meteoblue-widget`, lire `HANDOFF.md` et `WATCH_INSTALL.md`, puis exécuter `./Scripts/prepare_watch_install.sh`. Ne me redonne pas cette procédure : exécute-la.