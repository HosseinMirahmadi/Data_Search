# syntax=docker/dockerfile:1.6

# ---------------------------
# 1️⃣ Base image
# ---------------------------
FROM docker.arvancloud.ir/node:20-alpine AS base
WORKDIR /app
ENV NEXT_TELEMETRY_DISABLED=1

# ---------------------------
# 2️⃣ Dependencies (cached)
# ---------------------------
FROM base AS deps
# Copy only package files first (cache-friendly)
COPY package.json package-lock.json* ./

# Install ALL dependencies (including devDependencies)
RUN --mount=type=cache,target=/root/.npm \
    npm ci --legacy-peer-deps --no-fund --no-audit

# ---------------------------
# 3️⃣ Builder stage
# ---------------------------
FROM base AS builder
WORKDIR /app

# Copy dependencies and source
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Build Next.js app
COPY .env.production .env.production
RUN npm run build

# ---------------------------
# 4️⃣ Production image
# ---------------------------
FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

# Create non-root user
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Copy minimal build output only (standalone build)
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY .env.production .env.production

# Use non-root user
USER nextjs

EXPOSE 3000
CMD ["node", "server.js"]

