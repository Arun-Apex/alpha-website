FROM node:20-alpine

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci --omit=dev || npm install --omit=dev

# Copy app files
COPY . .

ENV NODE_ENV=production
EXPOSE 3000

CMD ["npm", "start"]