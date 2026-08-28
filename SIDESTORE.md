# Installation gratuite sur iPhone avec SideStore

Cette voie est recommandee pour utiliser Meteoblue Weather et son widget iPhone sans abonnement Apple Developer et sans posseder de Mac.

## Principe

- GitHub Actions compile l'app iPhone, son extension WidgetKit, l'app Apple Watch et sa complication WidgetKit sur un runner macOS.
- Le CI continue donc de verifier que les targets Watch compilent correctement.
- L'IPA remise a SideStore contient volontairement uniquement l'app iPhone et son widget iPhone.
- Le fichier `.ipa` reste non signe.
- SideStore le re-signe avec le certificat de developpement gratuit lie au compte Apple de l'utilisateur.
- SideStore renouvelle ensuite la signature de 7 jours directement depuis l'iPhone.

La voie iPhone + widget est maintenant validee de bout en bout sur appareil reel. Avec la build 1.0.3 (7), SideStore est reste ouvert apres installation, l'app s'est lancee, son icone a ete affichee correctement, le widget est apparu dans la galerie WidgetKit et le widget a affiche des donnees meteoblue. La variante precedente qui contenait aussi l'app Watch et sa complication faisait crasher SideStore environ une a deux secondes apres l'envoi du fichier. Les bundles Watch sont donc exclus du paquet SideStore, tout en restant compiles et testes dans le projet.

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

Chaque run manuel attribue automatiquement un `CFBundleVersion` distinct derive du numero de run GitHub et de sa tentative. Cela evite de produire deux IPA differentes portant exactement le meme numero de build, situation qui avait rendu une reinstallation de la build 6 ambigue pendant les tests materiels.

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
3. SideStore affiche `App Contains Extensions` car le paquet contient le widget. Choisir **Keep App Extensions (Use Main Profile)**. La validation materielle confirme que ce mode conserve correctement le widget : l'extension apparait dans la galerie WidgetKit et affiche les donnees meteoblue.
4. Laisser la barre de progression aller au bout. Sur la build 7 de validation, SideStore est reste ouvert et l'installation s'est terminee normalement. Lors d'une reinstallation anterieure de la meme build 6, SideStore s'etait ferme a la fin alors que l'app etait tout de meme installee. Si ce comportement reapparait, verifier d'abord l'etat de l'app avant de reimporter l'IPA.
5. Ouvrir Meteoblue Weather depuis l'ecran d'accueil, la Bibliotheque d'apps ou la recherche Spotlight.
6. Autoriser la localisation `Lorsque l'app est activee`.
7. Ajouter le grand widget Meteoblue Weather a l'ecran d'accueil.
8. Autoriser la localisation du widget si iOS affiche la demande.
9. Sur iOS 27 ou plus recent, maintenir le widget, choisir **Modifier le widget**, puis regler **Action au toucher** sur **Ouvrir une app -> meteoblue**. Sur les versions anterieures, aucun raccourci Shortcuts n'est necessaire : le widget transmet l'URL HTTPS meteoblue exacte du snapshot affiche a l'app hote, qui la valide puis tente de l'ouvrir comme Universal Link dans l'app meteoblue officielle. Si iOS a memorise une preference d'ouverture web pour `meteoblue.com`, le navigateur peut s'ouvrir a la place ; voir la procedure de reinitialisation plus bas.

### Que signifie `Active` dans SideStore ?

`Active` est simplement la section de `My Apps` dans laquelle SideStore liste les applications actuellement signees et installees. Meteoblue Weather doit y apparaitre avec une duree restante, normalement `7 DAYS` juste apres signature.

Ce statut n'est plus necessaire pour diagnostiquer la build 7 : la validation la plus forte est que l'app se lance sur iOS et que son widget apparaisse puis affiche effectivement la meteo. Les deux ont ete verifies sur appareil reel.

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

- attribue un numero de build SideStore unique a chaque run/tentative ;
- construit d'abord l'app Release complete et verifie que l'app Watch existe bien dans le produit de build ;
- retire ensuite les bundles Watch uniquement de la copie destinee a SideStore ;
- refuse l'IPA si l'app iPhone ou son widget manque ;
- refuse l'IPA si un bundle `.app` imbrique subsiste ;
- exige comme unique bundle imbrique `PlugIns/MeteoblueWidgetExtension.appex` ;
- verifie les deux bundle identifiers iPhone ;
- exige que l'app et le widget aient exactement les memes versions marketing et build ;
- exige que le numero de build compile corresponde au numero unique calcule pour le run ;
- exige un `Assets.car` non vide et une icone principale declaree dans `CFBundleIcons` ;
- refuse un `embedded.mobileprovision` inattendu ;
- refuse le paquet si la cle Meteoblue apparait encore en clair ;
- verifie l'integrite ZIP de l'IPA avant upload.

Cette transformation ne supprime pas le code Watch du depot et ne masque pas une erreur de compilation Watch : le CI compile toujours l'app Watch et sa complication separement avant de produire l'IPA.

## Ouverture de meteoblue depuis le widget

Le widget conserve l'URL meteoblue exacte du lieu et de l'altitude correspondant aux donnees affichees.

- Sur iOS 27 et plus recent, la configuration interactive utilise `RunSystemShortcutIntent` avec l'app choisie dans **Action au toucher**.
- Sur les versions anterieures, `widgetURL` transmet l'URL HTTPS meteoblue du snapshot a l'app Meteoblue Weather. WidgetKit active d'abord l'app qui possede le widget ; `onOpenURL` valide alors strictement la cible `meteoblue.com`, puis `UIApplication.open` la transmet a iOS avec `universalLinksOnly` afin d'ouvrir l'app meteoblue officielle si iOS route actuellement ce domaine vers l'app.
- Si iOS ne route pas l'Universal Link vers l'app, l'app hote retente la meme URL sans `universalLinksOnly`, ce qui ouvre la prevision meteoblue sur le web plutot que d'echouer silencieusement.

La build SideStore 1.0.3 (88.1) a valide physiquement toute cette chaine jusqu'au fallback : le toucher du widget a bien ete recu, l'URL de prevision a ete transmise et le navigateur s'est ouvert. Apres ce test, les deux sources d'association ont ete recontrolees : le fichier `apple-app-site-association` servi par `www.meteoblue.com` et sa copie servie par le CDN Apple declarent tous deux l'app actuelle `4UV5CK2DRM.com.meteoblue.meteoblue-weather` ainsi que le chemin francais `/*/meteo/semaine/*`. Le bundle App Store actuel est `com.meteoblue.meteoblue-weather`. Le format d'URL genere par Meteoblue Weather est donc bien dans le perimetre Universal Links de meteoblue.

### Reinitialiser l'ouverture vers l'app meteoblue

Apple memorise le choix de l'utilisateur entre l'app et le site web pour un domaine Universal Links. Une preference web memorisee peut donc faire ouvrir Safari ou le navigateur alors que l'app est installee et que l'association est valide.

La methode la plus explicite pour retablir l'app est :

1. Depuis la page meteoblue ouverte par le widget, copier son URL HTTPS.
2. Coller cette URL dans une note de l'app **Notes** d'Apple.
3. Faire un appui long sur le lien dans Notes.
4. Choisir **Ouvrir dans meteoblue** / **Open in meteoblue** si cette option est proposee, et non l'ouverture dans le navigateur.
5. Revenir a l'ecran d'accueil puis toucher de nouveau le widget Meteoblue Weather.

Apple documente que le choix effectue depuis ce menu devient le comportement par defaut pour ce domaine. Une autre possibilite, dans Safari, est de toucher **OPEN / OUVRIR** dans le Smart App Banner de meteoblue ; la page meteoblue publie bien `apple-itunes-app` pour l'App Store ID `994459137`.

Cette reinitialisation ne necessite **aucune nouvelle IPA** : la build 88.1 contient deja le bon Universal Link et son fallback web. Si l'option **Ouvrir dans meteoblue** est absente dans Notes, ou si le widget continue d'ouvrir le navigateur apres l'avoir selectionnee, il faut alors poursuivre le diagnostic de l'etat Associated Domains sur l'iPhone.

## Validation materielle du 28 aout 2026

Resultats observes sur l'iPhone de validation :

- IPA app iPhone + widget iPhone + app Watch + complication : SideStore crashe environ 1 a 2 secondes apres l'import ;
- IPA app iPhone + widget iPhone, sans Watch : import SideStore reussi ;
- build 1.0.3 (7) : SideStore reste ouvert apres installation ;
- Meteoblue Weather se lance correctement ;
- l'icone de l'app est correctement affichee ;
- le grand widget Meteoblue Weather est disponible dans la galerie de widgets ;
- le widget affiche effectivement les donnees meteoblue avec l'extension conservee via **Keep App Extensions (Use Main Profile)** ;
- build 1.0.3 (88.1) : toucher le widget pre-iOS 27 active correctement le relais puis ouvre la prevision dans le navigateur, ce qui valide le fallback web et revele un routage Universal Links de `meteoblue.com` vers le web sur cet iPhone.

La chaine gratuite **GitHub Actions -> IPA iPhone + widget -> SideStore -> iPhone -> WidgetKit** est donc validee de bout en bout pour l'installation et l'affichage meteo. Le dernier controle d'ouverture directe consiste a reinitialiser la preference Universal Link de l'iPhone avec **Ouvrir dans meteoblue** puis a retoucher le widget.

## Apple Watch

L'app Watch et sa complication restent implementees et testees dans le projet, mais elles ne sont actuellement pas distribuees par SideStore.

Le paquet Watch imbrique est le facteur discriminant observe dans le crash d'import. Tant qu'une chaine de signature/deploiement Watch compatible SideStore n'est pas etablie et testee, la voie gratuite recommandee reste SideStore pour l'iPhone et son widget uniquement. Une installation Watch pourra etre retestee separement si SideStore ajoute ou documente une prise en charge fiable des bundles watchOS, ou via Xcode sur Mac avec une Personal Team.

## Limitation a connaitre

La voie SideStore iPhone + widget est maintenant validee sur appareil reel, y compris l'affichage effectif de la meteo dans le widget. Les principaux comportements qui restent sous le controle d'iOS sont la cadence de rafraichissement WidgetKit, la livraison de nouvelles positions GPS lors des deplacements, les choix de permissions de localisation et le routage final des Universal Links selon la preference memorisee par l'utilisateur. La distribution de l'app Watch reste egalement hors du chemin SideStore valide.