# Build stage
FROM --platform=linux/amd64 node:20.17.0-alpine AS builder
WORKDIR /app

ARG NODE_ENV=development
ENV NODE_ENV=${NODE_ENV}

COPY package*.json ./
RUN npm ci --include=dev
COPY . .
RUN npm run build

# Production stage
FROM --platform=linux/amd64 node:20.17.0-alpine AS runner
WORKDIR /app

ARG NODE_ENV=development
ENV NODE_ENV=${NODE_ENV}
ENV PATH /app/node_modules/.bin:$PATH

# Add global installation of next.js
#RUN npm install -g next

COPY package*.json ./
RUN npm ci --only=production

COPY --from=builder /app/package*.json ./
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/next.config.mjs ./

EXPOSE 3000
CMD ["npm", "start"]
