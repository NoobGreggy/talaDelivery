# syntax=docker/dockerfile:1
###############################################################################
# TalaDelivery service image — single multi-stage Dockerfile for every app.
#
# Build with:
#   docker build --build-arg APP_NAME=order-service -t taladelivery/order-service .
#
# The runtime image runs the compiled app as an unprivileged user.
###############################################################################

FROM node:22-alpine AS base
WORKDIR /app
ENV NODE_ENV=production
ENV CI=true

# ---------------------------------------------------------------------------
# Dependencies: copy manifests, install everything (mixed dev+prod is needed
# because the monorepo compiles all apps from source; see build stage).
# ---------------------------------------------------------------------------
FROM base AS deps
RUN apk add --no-cache python3 make g++ dumb-init
COPY package.json package-lock.json ./
RUN npm ci --include=dev --no-audit --no-fund

# ---------------------------------------------------------------------------
# Build: copy sources and compile the requested app with nest build.
# ---------------------------------------------------------------------------
FROM deps AS build
ARG APP_NAME=api-gateway
COPY . .
RUN npx nest build ${APP_NAME}

# ---------------------------------------------------------------------------
# Runtime: production node_modules + compiled output + entrypoint.
# ---------------------------------------------------------------------------
FROM base AS runtime
ARG APP_NAME=api-gateway
ENV APP_NAME=${APP_NAME}
ENV PORT=3000

RUN apk add --no-cache dumb-init \
  && addgroup -S tala && adduser -S -G tala tala

# Full dependency tree (incl. devDeps) so compiled output + ts-node tooling
# (migrations) work at runtime. The builder image is disposable.
COPY --from=build /app/node_modules /app/node_modules
# Compiled output (dist/apps/<app>). Nest libs compile into dist/libs.
COPY --from=build /app/dist /app/dist
# Sources are needed for typeorm CLI migration paths in the migrate service.
COPY --from=build /app/apps /app/apps
COPY --from=build /app/libs /app/libs
COPY --from=build /app/package.json /app/package.json
COPY --from=build /app/nest-cli.json /app/nest-cli.json
COPY --from=build /app/tsconfig.base.json /app/tsconfig.base.json

USER tala
EXPOSE 3000

HEALTHCHECK --interval=15s --timeout=5s --start-period=20s --retries=5 \
  CMD node -e "fetch('http://127.0.0.1:'+process.env.PORT+'/health/ready').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

ENTRYPOINT ["dumb-init", "--"]
CMD ["sh", "-c", "TS_NODE_PROJECT=tsconfig.base.json TS_NODE_BASEURL=./dist/apps/${APP_NAME} node -r tsconfig-paths/register dist/apps/${APP_NAME}/apps/${APP_NAME}/src/main.js"]
