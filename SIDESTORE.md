# Installation gratuite sur iPhone avec SideStore

Cette voie est recommandee pour utiliser le widget sans abonnement Apple Developer et sans posseder de Mac.

## Principe

- GitHub Actions compile l'app et son extension WidgetKit sur un runner macOS.
- Le fichier `.ipa` reste non signe.
- SideStore le re-signe avec le certificat de developpement gratuit lie au compte Apple de l'utilisateur.
- SideStore renouvelle ensuite la signature de 7 jours directement depuis l'iPhone.

Un ordinateur Windows, macOS ou Linux reste necessaire une seule fois pour installer SideStore et associer l'iPhone. Apres cette etape, l'installation, la mise a jour et le renouvellement des apps se font depuis l'iPhone avec LocalDevVPN actif.

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

Pour eviter de publier en permanence une IPA contenant la cle Meteoblue, le packaging SideStore n'est lance que manuellement.

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
3. Laisser SideStore signer et installer l'app et son extension WidgetKit.
4. Ouvrir Meteoblue Weather.
5. Autoriser la localisation `Lorsque l'app est activee`.
6. Ajouter le grand widget Meteoblue Weather a l'ecran d'accueil.
7. Autoriser la localisation du widget si iOS affiche la demande.

## 4. Renouvellement gratuit

Le profil de developpement gratuit Apple expire au bout de 7 jours. SideStore peut le renouveler directement depuis l'iPhone ; il faut simplement que LocalDevVPN soit actif lorsque SideStore installe, met a jour ou rafraichit les apps.

Le compte gratuit impose aussi des limites d'App ID et d'apps actives. L'app Meteoblue Weather comporte une extension WidgetKit, qui utilise un App ID supplementaire lors de la signature. Le projet n'utilise pas App Groups, WeatherKit, Associated Domains ou une autre capability payante/avancee.

## Cle Meteoblue

Le depot ne contient jamais la cle en clair. Lors d'un `workflow_dispatch`, GitHub Actions lit le secret existant `METEOBLUE_API_KEY`, genere uniquement sur le runner une source Swift avec deux tableaux d'octets XOR aleatoires, compile l'app puis supprime le runner. Le workflow verifie aussi que la cle n'apparait pas en clair dans les fichiers de l'app avant de creer l'IPA.

Cette mesure est une obfuscation, pas un coffre-fort : une cle embarquee dans une app native peut toujours etre extraite par un attaquant determine. Le depot etant public, l'artefact manuel ne doit pas etre considere secret ; c'est pourquoi il n'est cree qu'a la demande et expire au bout d'un jour. Pour une protection cryptographique reelle, il faudrait un proxy HTTPS ou le mecanisme de signature Meteoblue avec secret partage.

## Limitation a connaitre

SideStore prend en charge les apps avec extensions et indique que les apps ne devraient normalement pas necessiter de modification. Il existe toutefois des bugs SideStore ponctuels autour des widgets/extensions selon les versions iOS. Notre widget evite notamment App Groups, ce qui contourne la categorie de bug actuellement ouverte sur les entitlements App Groups des extensions/widgets. Le premier essai sur l'iPhone reste donc la validation finale de la chaine de signature.
