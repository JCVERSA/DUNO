# DUNO — XFCE desktop in the browser, streamed with Selkies.
#
# Selkies base (X11/Xvfb, audio, GPU wiring, s6 supervision, Selkies server)
# + XFCE desktop + Firefox. Single TCP port, WebSockets transport.
# Railway-ready: listens on $PORT when injected, plain HTTP (the Railway
# TCP proxy does not terminate TLS), open access like the previous VNC setup
# (see README security note; set SELKIES_ENABLE_BASIC_AUTH=true + PASSWD
# to require a login).
#
# Follows the upstream "Building a desktop on it" pattern:
# https://docs.selkies.io/components/base-image
# Reference: addons/desktop/Dockerfile in selkies-project/selkies.

# Release tag for stability. Override at build time if needed, e.g.:
#   docker build --build-arg BASE_IMAGE=ghcr.io/selkies-project/selkies/base:main-ubuntu26.04 .
ARG BASE_IMAGE="ghcr.io/selkies-project/selkies/base:latest-ubuntu26.04"

FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="DUNO"
LABEL org.opencontainers.image.description="XFCE desktop streamed to the browser with Selkies (WebSockets, single port). Railway-ready."
LABEL org.opencontainers.image.source="https://github.com/JCVERSA/DUNO"
LABEL org.opencontainers.image.licenses="MIT"

ARG DEBIAN_FRONTEND="noninteractive"

# The base image is rootless (layers run as uid 1000 through fakeroot) while
# its setuid/setgid files belong to root. Bracket package work with the pair
# the image ships, or an archive update to those packages fails the layer.
USER 0
SHELL ["/bin/sh", "-c"]
RUN selkies-privileged-files release

USER 1000
SHELL ["/usr/bin/fakeroot", "--", "/bin/sh", "-c"]

# XFCE desktop, minimal but functional (same desktop family as before).
# dbus-x11 provides dbus-launch, used by the s6 service to start the session.
RUN apt-get clean && apt-get update && apt-get install --no-install-recommends -y \
        xfce4-session \
        xfwm4 \
        xfce4-panel \
        xfdesktop4 \
        xfce4-settings \
        xfce4-terminal \
        thunar \
        mousepad \
        xfce4-pulseaudio-plugin \
        pavucontrol \
        xterm \
        dbus-x11 \
        libnotify-bin \
        xubuntu-icon-theme \
        adwaita-icon-theme \
        gvfs \
        gvfs-daemons \
        fonts-dejavu \
        fonts-liberation \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/debconf/* /var/log/* /tmp/* /var/tmp/*

# Firefox from Mozilla's own APT repository (real .deb builds, pinned over the
# distribution package) — same approach as the upstream reference image.
# No PPA needed on this base.
RUN mkdir -pm755 /etc/apt/keyrings /etc/apt/sources.list.d /etc/apt/preferences.d && \
    curl -o /etc/apt/keyrings/packages.mozilla.org.asc -fsSL --retry 5 --retry-all-errors --retry-delay 3 --retry-connrefused --retry-max-time 180 "https://packages.mozilla.org/apt/repo-signing-key.gpg" && \
    printf 'Types: deb\nURIs: https://packages.mozilla.org/apt\nSuites: mozilla\nComponents: main\nSigned-By: /etc/apt/keyrings/packages.mozilla.org.asc\n' > /etc/apt/sources.list.d/mozilla.sources && \
    printf 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n' > /etc/apt/preferences.d/mozilla && \
    apt-get clean && apt-get update && \
    apt-get install --no-install-recommends -y firefox && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/debconf/* /var/log/* /tmp/* /var/tmp/*

# s6 service for the XFCE session + Railway-friendly entrypoint wrapper.
COPY --chown=1000:1000 services/ /etc/service/
COPY --chown=1000:1000 entrypoint/duno-entrypoint.sh /etc/duno-entrypoint.sh
RUN find /etc/service/xfce \( -name run -o -name finish \) -exec chmod -f 755 {} + && \
    chmod -f 755 /etc/duno-entrypoint.sh

# Restore privileged files, then fix ownership/bits of setuid/setgid helpers
# the new packages brought (fakeroot cannot set those for real).
USER 0
SHELL ["/bin/sh", "-c"]
RUN selkies-privileged-files restore && \
    for helper in /usr/lib/polkit-1/polkit-agent-helper-1 /usr/libexec/polkit-agent-helper-1 /usr/bin/pkexec; do \
        if [ -e "$helper" ]; then chown -f root:root "$helper" && chmod -f 4755 "$helper" || echo "Failed to restore setuid for $helper"; fi; \
    done && \
    for helper in /usr/lib/*/utempter/utempter /usr/libexec/utempter/utempter; do \
        if [ -e "$helper" ]; then chown -f root:utmp "$helper" && chmod -f 2755 "$helper" || echo "Failed to restore setgid for $helper"; fi; \
    done

USER 1000
ENV SHELL=/bin/bash
ENV USER=ubuntu
ENV HOME=/home/ubuntu
WORKDIR /home/ubuntu

# Defaults: WebSockets on one port, plain HTTP (Railway TCP proxy forwards
# raw TCP without TLS termination), open access like the previous VNC setup.
# All overridable with -e / Railway variables. The listening port itself is
# resolved dynamically by the entrypoint: SELKIES_PORT, else $PORT (Railway),
# else 8080.
ENV START_XFCE="true"
ENV SELKIES_MODE="websockets"
ENV SELKIES_ENABLE_HTTPS="false"
ENV SELKIES_ENABLE_BASIC_AUTH="false"

EXPOSE 8080

ENTRYPOINT ["/etc/duno-entrypoint.sh"]
