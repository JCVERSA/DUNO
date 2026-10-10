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
//   http://<host>.proxy.rlwy.net:<port>/
// URL that serves the desktop. The container listens on Railway's $PORT
// automatically and serves plain HTTP, which is what the TCP proxy forwards.
//
// Adjust the project/service names and the GitHub repo/branch to yours.

export default defineRailway(() => {
  const duno = service("duno", {
    source: github("JCVERSA/DUNO", { branch: "main" }),
    // Dockerfile at the repo root is picked up automatically (no build/start
    // commands: the image defines its own ENTRYPOINT).
    healthcheck: "/",
    healthcheckTimeout: 300, // desktop + X server boot can be slow on first start
    env: {
      // Mirror of the image defaults (see Dockerfile): WebSockets on one
      // port, plain HTTP for the TCP proxy, open access like the old VNC.
      SELKIES_MODE: "websockets",
      SELKIES_ENABLE_HTTPS: "false",
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
