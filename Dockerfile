FROM node:20-alpine AS build
WORKDIR /app

COPY backend/package*.json ./
RUN npm install

COPY backend/tsconfig.json ./tsconfig.json

# ⬇️ ADD THIS LINE (copies your environment variables)
COPY backend/.env .env

COPY backend/src ./src
RUN npm run build

FROM node:20-alpine
WORKDIR /app

ENV NODE_ENV=production

COPY backend/package*.json ./
RUN npm install --omit=dev

COPY --from=build /app/dist ./dist

# ⬇️ COPY THE ENV INTO FINAL IMAGE TOO
COPY backend/.env .env

EXPOSE 3000
CMD ["node", "dist/index.js"]
