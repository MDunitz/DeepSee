# DeepSee as one image: the Vue interface is built in a Node stage, then served by the
# Flask interpolation server, so the page and /getInterp share one origin and one port.
#
# Build (Podman or Docker):  podman build -f Containerfile -t deepsee .
# Run:                       podman run -d --name deepsee -p 127.0.0.1:8002:3000 deepsee
#
# Cruise data lives in /deepsee/interface/dist/assets (config.json, data/, meta/,
# backgrounds/). The bundled Pescadero cruise is the default; mount a folder over
# that path to serve other cruises without rebuilding.

FROM docker.io/library/node:16-bullseye AS interface
WORKDIR /build
COPY interface/package.json interface/package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY interface/ ./
# Empty backend URL: the page calls /getInterp on the server that served it.
ENV VUE_APP_BACKEND_URL=""
RUN npm run build

FROM docker.io/library/python:3.9-slim-bullseye
WORKDIR /deepsee/server
COPY server/requirements-container.txt ./
RUN pip install --no-cache-dir -r requirements-container.txt
COPY server/app.py ./
COPY --from=interface /build/dist /deepsee/interface/dist

ENV DEEPSEE_STATIC_DIR=/deepsee/interface/dist \
    PORT=3000
EXPOSE 3000
# Run as an unprivileged user inside the container.
RUN useradd --system --no-create-home deepsee
USER deepsee
CMD ["python", "app.py"]
