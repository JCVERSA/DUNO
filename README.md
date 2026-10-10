# DUNO

Bureau XFCE accessible depuis un navigateur, streamé avec [Selkies](https://github.com/selkies-project/selkies) (WebSockets, un seul port TCP). Prêt pour Railway.

> Migration depuis TigerVNC + noVNC : plus de port VNC, plus de `/vnc.html` — le client Selkies est servi à la racine `/`.

## Déployer sur Railway (chemin recommandé)

1. Crée un service depuis ce repo GitHub. Railway détecte le `Dockerfile` tout seul (builder `DOCKERFILE`, pas de build/start command : l'image définit son `ENTRYPOINT`).
2. Dans **Networking**, ajoute un **TCP Proxy** vers le port du service. Tu obtiens une URL publique du type :
   ```
   http://altaria.proxy.rlwy.net:47977/
   ```
3. Ouvre l'URL : le bureau XFCE s'affiche. C'est tout — le conteneur écoute automatiquement sur le `$PORT` injecté par Railway, en HTTP pur (le TCP proxy ne termine pas TLS).

Alternative reproductible : `.railway/railway.ts` (Infrastructure as Code, à appliquer via la CLI `railway config plan` / `railway config apply`). Le TCP proxy reste à activer dans le dashboard dans tous les cas.

## Lancer en local

```bash
docker build . -t duno
docker run -it --rm -p 8080:8080 --shm-size=2g duno
```

Puis ouvrir http://localhost:8080/ ( Selkies écoute sur `SELKIES_PORT`, `$PORT`, ou `8080` par défaut).

## Variables d'environnement

| Variable | Défaut | Rôle |
|---|---|---|
| `PORT` | — (injecté par Railway) | Port d'écoute pris en compte automatiquement |
| `SELKIES_PORT` | `8080` | Surcharge explicite du port d'écoute |
| `SELKIES_MODE` | `websockets` | Transport. `webrtc` = latence minimale mais **incompatible avec le TCP proxy Railway** (pas d'UDP) |
| `SELKIES_ENABLE_HTTPS` | `false` | `true` uniquement si tu termines TLS toi-même (certificat + client en `https://`) |
| `SELKIES_ENABLE_BASIC_AUTH` | `false` | `true` + `PASSWD=...` pour exiger un login (user `ubuntu`) |
| `PASSWD` | `mypasswd` (image de base) | Mot de passe du compte et du login web quand l'auth est activée |
| `START_XFCE` | `true` | `false` = serveur d'affichage seul, sans session XFCE |
| `TZ` | — | Fuseau horaire (ex. `Europe/Paris`) |
| `DISPLAY_SIZEW` / `DISPLAY_SIZEH` | `1920` / `1080` | Résolution initiale (le redimensionnement dynamique suit la fenêtre du client par défaut) |

`SELKIES_WAYLAND=true` n'est **pas** supporté par la couche XFCE (XFCE est un bureau X11) : garde le backend X11 par défaut.

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

## Contenu du repo

```
Dockerfile                  FROM selkies/base + XFCE + Firefox + service s6
entrypoint/duno-entrypoint.sh   Mappe $PORT (Railway) vers SELKIES_PORT
services/xfce/              Service s6 (run/finish) de la session XFCE
.railway/railway.ts         Config Railway (IaC, via CLI)
```

## Licences

- DUNO (ce repo) : MIT, voir `LICENSE`.
- Image de base et serveur Selkies : [MPL-2.0](https://www.mozilla.org/en-US/MPL/2.0/) (`selkies-project/selkies`). Les fichiers de ce repo restent des œuvres séparées sous MIT.
