# syntax=docker/dockerfile:1
# One shared image compiles every service once; APP_NAME selects the process.
FROM node:22-alpine AS deps
WORKDIR /app
ENV CI=true
RUN apk add --no-cache python3 make g++
COPY package.json package-lock.json ./
RUN npm ci --include=dev --no-audit --no-fund

FROM deps AS build
COPY . .
RUN for app in api-gateway identity-service merchant-service catalog-service order-service dispatch-service payment-service notification-service realtime-service; do \
      ./node_modules/.bin/nest build "$app" || exit 1; \
    done

# TypeScript and tooling are retained only in the one-shot migration image.
FROM build AS migrate
ENV NODE_ENV=production
CMD ["npm", "run", "migration:run"]

FROM build AS production-deps
RUN npm prune --omit=dev --no-audit --no-fund

FROM node:22-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
ENV APP_NAME=api-gateway
ENV PORT=3000
RUN apk add --no-cache dumb-init
COPY --from=production-deps --chown=node:node /app/node_modules ./node_modules
COPY --from=build --chown=node:node /app/dist ./dist
COPY --chown=node:node docker/start-service.cjs ./start-service.cjs
USER node
HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=10 \
  CMD node -e "fetch('http://127.0.0.1:'+process.env.PORT+'/health/ready').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "start-service.cjs"]
