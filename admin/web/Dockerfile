FROM node:18-alpine AS build
WORKDIR /app

# Allow passing the API URL at build time
ARG VITE_API_URL=http://api:8080
ENV VITE_API_URL=${VITE_API_URL}

COPY package.json package-lock.json* ./
# Ensure devDependencies (like Vite) are installed inside the build stage
# Some environments set npm config production=true; explicitly include dev deps
RUN npm ci --include=dev --legacy-peer-deps --no-audit --no-fund || \
	npm install --include=dev --legacy-peer-deps --no-audit --no-fund
COPY . ./
# Explicitly invoke Vite from local node_modules in case npm scripts path resolution fails
RUN node ./node_modules/vite/bin/vite.js build

FROM nginx:stable-alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
