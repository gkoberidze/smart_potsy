FROM node:20-alpine
WORKDIR /app

ENV NODE_ENV=production

COPY backend/package*.json ./
RUN npm install --omit=dev

COPY --from=build /app/dist ./dist

# MUST COPY ENV TO BOTH ROOT AND DIST
COPY backend/.env .env
COPY backend/.env ./dist/.env

EXPOSE 3000
CMD ["node", "dist/index.js"]
