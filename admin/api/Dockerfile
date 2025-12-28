FROM node:18-alpine
WORKDIR /app
COPY package.json package-lock.json /app/
RUN npm ci
COPY . /app
# Service account key is already included in the image
# Set fixed path for serviceAccountKey.json
ENV SERVICE_ACCOUNT_PATH=/app/serviceAccountKey.json
EXPOSE 8080
CMD ["node", "server.js"]
