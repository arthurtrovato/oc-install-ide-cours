# Installation gratuite sur iPhone avec SideStore

Cette voie est recommandee pour utiliser Meteoblue Weather et son widget iPhone sans abonnement Apple Developer et sans posseder de Mac.

## Principe

- GitHub Actions compile l'app iPhone, son extension WidgetKit, l'app Apple Watch et sa complication WidgetKit sur un runner macOS.
- Le CI continue donc de verifier que les targets Watch compilent correctement.
- L'IPA remise a SideStore contient volontairement uniquement l'app iPhone et son widget iPhone.
- Le fichier `.ipa` reste non signe.
- SideStore le re-signe avec le certificat de developpement gratuit lie au compte Apple de l'utilisateur.
- SideStore renouvelle ensuite la signature de 7 jours directement depuis l'iPhone.

La variante iPhone + widget a ete validee sur appareil reel : SideStore l'importe correctement. La variante precedente qui contenait aussi l'app Watch et sa complication faisait crasher SideStore environ une a deux secondes apres l'envoi du fichier. Les bundles Watch sont donc exclus du paquet SideStore, tout en restant compiles et testes dans le projet.

Un ordinateur Windows, macOS ou Linux reste necessaire une seule fois pour installer SideStore et associer l'iPhone. Apres cette etape, l'installation, la mise a jour et le renouvellement de l'app se font depuis l'iPhone avec LocalDevVPN actif.

Documentation officielle SideStore :

- https://docs.sidestore.io/docs/installation/prerequisites
- https://docs.sidestore.io/docs/installation/install
- https://docs.sidestore.io/docs/faq

## 1. Installer SideStore une seule fois

1. Sur l'iPhone, installer LocalDevVPN depuis l'App Store et autoriser sa configuration VPN.
2. Sur le PC, installer/lancer iLoader selon la documentation SideStore.
3. Brancher l'iPhone en USB, le faire confiance au PC, puis choisir `Install SideStore (Stable)`.
4. Sur l'iPhone, activer le mode Developpeur si iOS le demande.
5. Ouvrir SideStore, terminer la connexion au compte Apple et effectuer un premier `Refresh` avant d'installer Meteoblue Weather.

## 2. Generer l'IPA Meteoblue Weather

Pour eviter de publier en permanence une IPA contenant la cle Meteoblue, le packaging SideStore n'est lance que manuellement. Les pushes ordinaires continuent de tester l'app iPhone, le widget, l'app Watch et la complication, mais ils ne generent pas la cle embarquee ni l'IPA.

Depuis l'iPhone :

1. Ouvrir le depot GitHub.
2. Ouvrir `Actions` puis `iOS CI`.
3. Appuyer sur `Run workflow` en selectionnant la branche `meteoblue-widget`.
4. Attendre que le run soit vert.
5. Dans la section `Artifacts`, telecharger `MeteoblueWeather-SideStore`.
6. Ouvrir le ZIP dans Fichiers pour recuperer `MeteoblueWeather-SideStore.ipa`.

L'artefact est conserve seulement 1 jour.

## 3. Installer sur l'iPhone

1. Activer LocalDevVPN.
2. Depuis Fichiers, partager/ouvrir `MeteoblueWeather-SideStore.ipa` avec SideStore.
3. SideStore affiche `App Contains Extensions` car le paquet contient le widget. Choisir **Keep App Extensions (Use Main Profile)**. Cette option conserve le widget tout en evitant d'enregistrer inutilement un App ID distinct lorsqu'un profil principal partage peut etre utilise.
4. Laisser la barre de progression aller au bout. Sur l'iPhone de validation, SideStore s'est ferme juste apres cette phase lors d'une reinstallation de la meme build, mais l'ecran `My Apps` indiquait ensuite bien `Meteoblue Weather` dans `Active` avec `7 DAYS`. Dans ce cas, traiter l'installation comme reussie et verifier directement l'app sur iOS au lieu de relancer immediatement le meme IPA.
5. Ouvrir Meteoblue Weather depuis l'ecran d'accueil, la Bibliotheque d'apps ou la recherche Spotlight.
6. Autoriser la localisation `Lorsque l'app est activee`.
7. Ajouter le grand widget Meteoblue Weather a l'ecran d'accueil.
8. Autoriser la localisation du widget si iOS affiche la demande.
9. Sur iOS 27 ou plus recent, maintenir le widget, choisir **Modifier le widget**, puis regler **Action au toucher** sur **Ouvrir une app -> meteoblue**.

### Comment savoir si l'installation a reussi

Dans SideStore > `My Apps`, Meteoblue Weather doit apparaitre sous `Active` avec une duree restante, normalement `7 DAYS` juste apres signature. Si cette entree est presente, la signature/installation a ete acceptee par SideStore meme si son interface s'est fermee a la fin de l'operation.

Ne pas confondre ce cas avec le crash d'import de l'ancienne IPA Watch : dans ce dernier cas SideStore disparaissait environ une a deux secondes apres l'envoi du fichier, avant que Meteoblue Weather ne soit installee comme app active.

## 4. Renouvellement gratuit et App IDs

Le profil de developpement gratuit Apple expire au bout de 7 jours. SideStore peut le renouveler directement depuis l'iPhone ; il faut simplement que LocalDevVPN soit actif lorsque SideStore installe, met a jour ou rafraichit l'app.

SideStore documente deux limites importantes pour un compte Apple gratuit : jusqu'a 3 apps actives a la fois (SideStore compris) et jusqu'a 10 App IDs par semaine. Les extensions peuvent consommer des App IDs lors de la signature selon le mode de profil choisi.

Le paquet SideStore Meteoblue Weather contient exactement deux bundle identifiers :

- `com.arthurtrovato.MeteoblueWidget` - app iPhone ;
- `com.arthurtrovato.MeteoblueWidget.Widget` - widget iPhone.

Les deux bundle identifiers Watch existent toujours dans le projet mais ne sont pas inclus dans l'IPA SideStore :

- `com.arthurtrovato.MeteoblueWidget.watchkitapp` - app Apple Watch ;
- `com.arthurtrovato.MeteoblueWidget.watchkitapp.Widget` - complication/widget Watch.

Le projet n'utilise pas App Groups, WeatherKit, Associated Domains ou une autre capability payante/avancee.

## Cle Meteoblue

Le depot ne contient jamais la cle en clair. Lors d'un `workflow_dispatch`, GitHub Actions lit le secret existant `METEOBLUE_API_KEY`, genere uniquement sur le runner une source Swift avec deux tableaux d'octets XOR aleatoires, compile l'app puis supprime le runner. Le workflow verifie aussi que la cle n'apparait pas en clair dans les fichiers de l'app avant de creer l'IPA.

Cette mesure est une obfuscation, pas un coffre-fort : une cle embarquee dans une app native peut toujours etre extraite par un attaquant determine. Le depot etant public, l'artefact manuel ne doit pas etre considere secret ; c'est pourquoi il n'est cree qu'a la demande et expire au bout d'un jour. Pour une protection cryptographique reelle, il faudrait un proxy HTTPS ou le mecanisme de signature Meteoblue avec secret partage.

## Validation automatique du paquet

Lors du run manuel, le CI :

- construit d'abord l'app Release complete et verifie que l'app Watch existe bien dans le produit de build ;
- retire ensuite les bundles Watch uniquement de la copie destinee a SideStore ;
- refuse l'IPA si l'app iPhone ou son widget manque ;
- refuse l'IPA si un bundle `.app` imbrique subsiste ;
- exige comme unique bundle imbrique `PlugIns/MeteoblueWidgetExtension.appex` ;
- verifie les deux bundle identifiers iPhone ;
- refuse un `embedded.mobileprovision` inattendu ;
- refuse le paquet si la cle Meteoblue apparait encore en clair ;
- verifie l'integrite ZIP de l'IPA avant upload.

Cette transformation ne supprime pas le code Watch du depot et ne masque pas une erreur de compilation Watch : le CI compile toujours l'app Watch et sa complication separement avant de produire l'IPA.

## Apple Watch

L'app Watch et sa complication restent implementees et testees dans le projet, mais elles ne sont actuellement pas distribuees par SideStore.

Validation materielle du 28 aout 2026 :

- IPA app iPhone + widget iPhone + app Watch + complication : SideStore crashe environ 1 a 2 secondes apres l'import ;
- IPA app iPhone + widget iPhone, sans Watch : import SideStore reussi.

Le paquet Watch imbrique est donc le facteur discriminant observe. Tant qu'une chaine de signature/deploiement Watch compatible SideStore n'est pas etablie et testee, la voie gratuite recommandee reste SideStore pour l'iPhone et son widget uniquement. Une installation Watch pourra etre retestee separement si SideStore ajoute ou documente une prise en charge fiable des bundles watchOS, ou via Xcode sur Mac avec une Personal Team.

## Limitation a connaitre

SideStore prend en charge l'app iPhone et son extension WidgetKit dans la configuration ci-dessus, qui a maintenant ete validee sur appareil reel. SideStore et iOS gardent toutefois la main sur la signature, les App IDs et les futurs changements de compatibilite. Si une mise a jour SideStore ou iOS modifie ce comportement, le test d'import sur appareil reste l'arbitre final.
