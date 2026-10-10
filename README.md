# DUNO

Bureau XFCE accessible depuis un navigateur, streamé avec [Selkies](https://github.com/selkies-project/selkies) (WebSockets, un seul port TCP). Prêt pour Railway.

> Migration depuis TigerVNC + noVNC : plus de port VNC, plus de `/vnc.html` — le client Selkies est servi à la racine `/`.

## Déployer sur Railway (chemin recommandé)

1. Crée un service depuis ce repo GitHub. Railway détecte le `Dockerfile` tout seul (builder `DOCKERFILE`, pas de build/start command : l'image définit son `ENTRYPOINT`).
2. Dans **Networking**, ajoute un **TCP Proxy** vers le port du service. Tu obtiens une URL publique du type :
   ```
   https://altaria.proxy.rlwy.net:47977/
   ```
3. Ouvre l'URL **en `https://`** : le bureau XFCE s'affiche. Le conteneur écoute automatiquement sur le `$PORT` injecté par Railway et termine TLS lui-même — le TCP proxy ne fait que relayer du TCP brut, il ne termine pas TLS.

> ⚠️ **Certificat auto-signé.** L'image sert HTTPS avec un certificat *snakeoil* généré au démarrage : le navigateur affichera un avertissement (« Votre connexion n'est pas privée », `NET::ERR_CERT_AUTHORITY_INVALID`). C'est attendu — « Avancé » puis « Continuer vers le site ». Le trafic est bien chiffré, seule l'identité du serveur n'est pas prouvée. Pour un certificat valide, place un reverse proxy qui termine TLS devant le service et passe `SELKIES_ENABLE_HTTPS=false`.

> Le client web Selkies **exige une connexion sécurisée** : servi en HTTP pur, il refuse de démarrer (« requires a secure connection »). D'où `SELKIES_ENABLE_HTTPS=true` par défaut. Ne le remets à `false` que derrière un reverse proxy qui termine TLS, sinon tu empiles du TLS dans du TLS.

Alternative reproductible : `.railway/railway.ts` (Infrastructure as Code, à appliquer via la CLI `railway config plan` / `railway config apply`). Le TCP proxy reste à activer dans le dashboard dans tous les cas.

## Lancer en local

```bash
docker build . -t duno
docker run -it --rm -p 8080:8080 --shm-size=2g duno
```

Puis ouvrir **https**://localhost:8080/ (Selkies écoute sur `SELKIES_PORT`, `$PORT`, ou `8080` par défaut) — avec le même avertissement de certificat auto-signé qu'en production. Pour du HTTP pur en local :

```bash
docker run -it --rm -p 8080:8080 --shm-size=2g -e SELKIES_ENABLE_HTTPS=false duno
```

et ouvre http://localhost:8080/.

## Variables d'environnement

| Variable | Défaut | Rôle |
|---|---|---|
| `PORT` | — (injecté par Railway) | Port d'écoute pris en compte automatiquement |
| `SELKIES_PORT` | `8080` | Surcharge explicite du port d'écoute |
| `SELKIES_MODE` | `websockets` | Transport. `webrtc` = latence minimale mais **incompatible avec le TCP proxy Railway** (pas d'UDP) |
| `SELKIES_ENABLE_HTTPS` | `true` | Le client web Selkies **exige** une connexion sécurisée. `true` = le conteneur termine TLS lui-même (certificat auto-signé, URL à ouvrir en `https://`). `false` **uniquement** derrière un reverse proxy qui termine TLS (domaine généré Railway, nginx, …) |
| `SELKIES_ENABLE_BASIC_AUTH` | `false` | `true` + `PASSWD=...` pour exiger un login (user `ubuntu`) |
| `PASSWD` | `mypasswd` (image de base) | Mot de passe du compte et du login web quand l'auth est activée |
| `START_XFCE` | `true` | `false` = serveur d'affichage seul, sans session XFCE |
| `TZ` | — | Fuseau horaire (ex. `Europe/Paris`) |
| `DISPLAY_SIZEW` / `DISPLAY_SIZEH` | `1920` / `1080` | Résolution initiale (le redimensionnement dynamique suit la fenêtre du client par défaut) |

`SELKIES_WAYLAND=true` n'est **pas** supporté par la couche XFCE (XFCE est un bureau X11) : garde le backend X11 par défaut.

> Note : au démarrage, l'entrypoint filtre les variables d'environnement dont la valeur contient des caractères hors `[A-Za-z0-9_.,:/+@%=-]` (multilignes, espaces, `$()`, `<mails>`, …), car l'entrypoint Selkies les recopie telles quelles dans `container-env` et cela casse le démarrage du serveur. À prendre en compte pour `PASSWD` si tu actives l'auth (Railway injecte ce type de métadonnées git, elles sont écartées automatiquement).

## Sécurité — à lire

L'accès est **libre, sans mot de passe** (comme l'ancien VNC) : quiconque connaît l'URL publique Railway contrôle le bureau et le Firefox dedans. Pour exiger un login :

```bash
SELKIES_ENABLE_BASIC_AUTH=true
PASSWD=un-vrai-mot-de-passe
```

## Dépannage

- **Le build échoue sur l'image de base** (tag `latest-ubuntu26.04` inconnu) : reconstruis avec la branche courante —
  `docker build --build-arg BASE_IMAGE=ghcr.io/selkies-project/selkies/base:main-ubuntu26.04 .`
- **`/vnc.html` n'existe plus** : le client est en `/`, sans sous-chemin.
- **Navigateur instable** : Selkies recommande `--shm-size=2g` en local (défaut Docker 64 Mo trop petit). Railway ne permet pas de régler `/dev/shm` : Firefox le tolère en général, mais les pages très lourdes peuvent en souffrir.
- **Healthcheck Railway** : chemin `/`, timeout 300 s (le premier démarrage X + XFCE + Selkies est lent).
- **Boucle `container-env ... not a valid identifier` + site injoignable** : c'était les métadonnées git multilignes injectées par Railway — l'entrypoint les filtre désormais avant le démarrage Selkies.
- **Le client affiche « requires a secure connection » / la page reste vide en `http://`** : le client web Selkies refuse un origin en HTTP pur. Ouvre l'URL en `https://` et passe l'avertissement de certificat auto-signé. Si tu es derrière un reverse proxy qui termine déjà TLS, mets au contraire `SELKIES_ENABLE_HTTPS=false` (sinon TLS dans TLS).
- **Avertissement de certificat à chaque visite** : normal, le certificat est auto-signé (snakeoil) et régénéré au démarrage. Seul un reverse proxy avec un certificat réel (Let's Encrypt) l'élimine.

## Contenu du repo

```
Dockerfile                  FROM selkies/base + XFCE + Firefox + service s6
entrypoint/duno-entrypoint.sh   Sanifie l'environnement (valeurs hostiles), puis mappe $PORT (Railway) vers SELKIES_PORT
services/xfce/              Service s6 (run/finish) de la session XFCE
tests/test-entrypoint.sh    Tests fonctionnels de l'entrypoint (à lancer sous sh ET bash)
.railway/railway.ts         Config Railway (IaC, via CLI)
```

## Licences

- DUNO (ce repo) : MIT, voir `LICENSE`.
- Image de base et serveur Selkies : [MPL-2.0](https://www.mozilla.org/en-US/MPL/2.0/) (`selkies-project/selkies`). Les fichiers de ce repo restent des œuvres séparées sous MIT.
