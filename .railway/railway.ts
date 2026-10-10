import { defineRailway, github, project, service } from "railway/iac";

// DUNO on Railway (Infrastructure as Code, applied via the Railway CLI —
// Railway does NOT read this file during deploys).
//
// Usage:
//   cd .railway && npm init -y && npm install railway
//   railway login && railway link   # link to your DUNO project/environment
//   railway config plan              # review
//   railway config apply             # apply after confirmation
//
// After apply, in the Railway dashboard (Networking), expose the service
// with a TCP Proxy (IaC has no TCP-proxy field): you get a public
//   https://<host>.proxy.rlwy.net:<port>/
// URL that serves the desktop. The container listens on Railway's $PORT
// automatically and terminates TLS itself — the TCP proxy only forwards raw
// TCP, it does not terminate TLS.
//
// Adjust the project/service names and the GitHub repo/branch to yours.

export default defineRailway(() => {
  const duno = service("duno", {
    source: github("JCVERSA/DUNO", { branch: "arena/e55e54df-duno" }),
    // Dockerfile at the repo root is picked up automatically (no build/start
    // commands: the image defines its own ENTRYPOINT).
    healthcheck: "/",
    healthcheckTimeout: 300, // desktop + X server boot can be slow on first start
    env: {
      // Mirror of the image defaults (see Dockerfile): WebSockets on one
      // port, open access like the old VNC.
      SELKIES_MODE: "websockets",
      // The Selkies web client requires a secure connection: over plain HTTP
      // it refuses to start ("requires a secure connection"). So TLS has to be
      // terminated by something, and which side does it depends on the setup:
      //   - TCP Proxy (the setup documented above): the proxy forwards raw TCP
      //     and does NOT terminate TLS, so the container must -> keep "true"
      //     and open the URL as https://<host>.proxy.rlwy.net:<port>/ (bypass
      //     the self-signed certificate warning in the browser).
      //   - Railway "Generated domain", or your own reverse proxy: TLS is
      //     already terminated in front of the container -> set "false",
      //     otherwise you stack TLS inside TLS and the client never connects.
      SELKIES_ENABLE_HTTPS: "true",
      SELKIES_ENABLE_BASIC_AUTH: "false",
      START_XFCE: "true",
      // To require a login instead (recommended on a public URL):
      //   SELKIES_ENABLE_BASIC_AUTH: "true",
      //   PASSWD: "change-me",
    },
  });

  return project("duno", {
    resources: [duno],
  });
});
