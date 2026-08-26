FROM node:18-alpine
RUN apk add --no-cache libc6-compat openssl
WORKDIR /app

COPY package.json package-lock.json ./
COPY apps/api/package.json ./apps/api/
COPY packages/shared/package.json ./packages/shared/
RUN NODE_OPTIONS="--max-old-space-size=4096" npm install --ignore-scripts

COPY . .
RUN npx prisma generate --schema=apps/api/prisma/schema.prisma
RUN cd apps/api && NODE_OPTIONS="--max-old-space-size=4096" npx nest build

COPY apps/api/docker-entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

ENV NODE_ENV=production
EXPOSE 3001
CMD ["sh", "/app/entrypoint.sh"]
