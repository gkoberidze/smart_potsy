# 1️⃣ Build stage
FROM node:20-alpine AS build
WORKDIR /app

COPY backend/package*.json ./
RUN npm install

COPY backend/tsconfig.json ./tsconfig.json
COPY backend/.env .env

COPY backend/src ./src
RUN npm run build

# 2️⃣ Runtime stage
FROM node:20-alpine
WORKDIR /app

ENV NODE_ENV=production

COPY backend/package*.json ./
RUN npm install --omit=dev

# Copy compiled code from build stage
COPY --from=build /app/dist ./dist

# MUST COPY ENV to both places
COPY backend/.env .env
COPY backend/.env ./dist/.env

EXPOSE 3000
CMD ["node", "dist/index.js"]
