# Installation de la complication Meteoblue sur Apple Watch

Cette procédure installe uniquement l'app Watch Meteoblue et sa complication rectangulaire via Xcode. Elle est volontairement séparée de SideStore : le paquet SideStore iPhone ne contient plus de bundle Watch, car l'import d'une IPA iPhone + widget + Watch + complication a fait crasher SideStore sur appareil réel.

## État du projet

- cible Watch : `MeteoblueWatch`
- extension WidgetKit : `MeteoblueWatchWidgetExtension`
- watchOS minimum : 10.0
- app Watch configurée avec `WKRunsIndependentlyOfCompanionApp = true`
- la complication utilise les données meteoblue
- toucher la complication doit volontairement ouvrir **Météo d'Apple sur la Watch**
- l'app Watch demande elle-même la localisation et effectue ses propres requêtes réseau

## Prérequis

- un Mac avec Xcode et le support watchOS installé ;
- l'iPhone compagnon de l'Apple Watch ;
- l'Apple Watch appairée à cet iPhone ;
- Developer Mode activé si Xcode le demande ;
- un Apple Account ajouté dans Xcode. Une Personal Team gratuite suffit pour tester sur ses propres appareils, avec les limites habituelles des profils de développement gratuits ;
- la clé meteoblue disponible localement dans `Config/Secrets.xcconfig`.

Apple documente que Xcode peut lancer une app watchOS sur une montre physique appairée au Mac via son iPhone compagnon. Pour une Apple Watch, il faut d'abord appairer l'iPhone compagnon avec le Mac dans Device Hub. Les Apple Watch Series 5 ou plus anciennes exigent explicitement que le Mac soit sur le même réseau Wi-Fi Bonjour que la montre ; ce prérequis Wi-Fi n'est pas formulé de la même manière pour les modèles plus récents.

Références Apple :

- https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices
- https://developer.apple.com/documentation/xcode/pairing-your-devices-with-your-mac
- https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device

## 1. Préparer la clé meteoblue

Dans le clone local du dépôt :

```sh
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
```

Puis éditer uniquement `Config/Secrets.xcconfig` :

```text
METEOBLUE_API_KEY = votre_cle_meteoblue
```

Ce fichier est ignoré par Git et ne doit jamais être commité.

## 2. Générer le projet Xcode

Depuis la racine du dépôt :

```sh
brew install xcodegen
xcodegen generate
open MeteoblueWeather.xcodeproj
```

## 3. Configurer la signature gratuite

Dans Xcode :

1. ouvrir **Xcode > Settings > Accounts** et ajouter l'Apple Account si nécessaire ;
2. sélectionner le projet `MeteoblueWeather` ;
3. sélectionner la target **MeteoblueWatch** ;
4. onglet **Signing & Capabilities** ;
5. garder **Automatically manage signing** activé ;
6. choisir la **Personal Team** correspondant au compte Apple ;
7. faire la même chose pour **MeteoblueWatchWidgetExtension** si Xcode ne l'hérite pas automatiquement.

Les bundle IDs Watch sont :

- `com.arthurtrovato.MeteoblueWidget.watchkitapp`
- `com.arthurtrovato.MeteoblueWidget.watchkitapp.Widget`

Si Xcode indique que ces identifiants sont déjà réservés par une autre équipe, modifier temporairement les bundle IDs Watch dans `project.yml` avec un suffixe unique avant de régénérer le projet. Ne pas modifier les bundle IDs iPhone/SideStore pour ce test.

## 4. Appairer la montre avec Xcode

1. connecter l'iPhone compagnon au Mac avec un câble ;
2. accepter **Faire confiance à cet ordinateur** si demandé ;
3. ouvrir **Window > Devices and Simulators** / Device Hub ;
4. sélectionner l'iPhone et terminer l'appairage ;
5. vérifier que l'Apple Watch apparaît comme destination associée ;
6. activer Developer Mode sur l'iPhone et/ou la Watch si Xcode le demande.

## 5. Installer uniquement l'app Watch

Dans la barre d'outils Xcode :

1. sélectionner le scheme **MeteoblueWatch** ;
2. sélectionner l'Apple Watch physique comme destination ;
3. cliquer sur **Run**.

Le scheme Watch contient uniquement la cible Watch et sa complication. `WKRunsIndependentlyOfCompanionApp = true` permet à l'app Watch de fonctionner sans exiger l'installation de l'app iPhone par Xcode.

Le CI `Watch CI` construit en plus cette cible pour `generic/platform=watchOS` et refuse le build si :

- l'app Watch n'est pas marquée indépendante ;
- la complication WidgetKit manque ;
- les bundle IDs Watch sont incohérents ;
- `NSWidgetWantsLocation` n'est pas activé ;
- les versions app/extension diffèrent.

## 6. Premier lancement sur la Watch

Après installation :

1. ouvrir **Meteoblue** sur l'Apple Watch ;
2. autoriser la localisation ;
3. vérifier que l'app ne signale pas `Clé meteoblue absente du build` ;
4. attendre un premier chargement météo ;
5. ajouter la complication **Meteoblue 5 h** dans un emplacement `.accessoryRectangular` du cadran.

La complication doit afficher :

- température actuelle ;
- maxi / mini du jour ;
- résumé de précipitations du jour ;
- les cinq prochaines heures avec pictogramme, température et pluie quand elle est significative.

## 7. Validation du comportement voulu au toucher

Toucher la complication doit suivre cette chaîne :

```text
Meteoblue complication
 -> meteobluewatch://apple-weather
 -> app Watch Meteoblue
 -> weather://
 -> app Météo d'Apple sur l'Apple Watch
```

Ce comportement est **volontaire**. Ne pas le remplacer par l'app meteoblue officielle sur Apple Watch.

## 8. Points à relever lors du premier test physique

Noter précisément :

- l'Apple Watch apparaît-elle comme destination Xcode ?
- l'installation réussit-elle ?
- l'app Meteoblue se lance-t-elle ?
- la permission de localisation apparaît-elle ?
- la complication apparaît-elle dans l'éditeur du cadran ?
- les données meteoblue réelles s'affichent-elles ?
- la timeline se met-elle à jour après quelques dizaines de minutes ?
- toucher la complication ouvre-t-il bien Météo d'Apple sur la Watch ?

En cas d'échec Xcode, conserver le message d'erreur exact : signature/provisioning, appairage, destination indisponible, installation ou runtime. Cela permettra de corriger uniquement la couche concernée.
