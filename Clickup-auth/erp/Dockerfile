FROM node:20-alpine

WORKDIR /app

# Install dependencies first (better layer caching)
COPY package*.json ./
RUN npm install --omit=dev

# Copy source code
COPY . .

ENV NODE_ENV=production
EXPOSE 3100

CMD ["node", "src/server.js"]
