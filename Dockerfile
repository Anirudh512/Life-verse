FROM ghcr.io/cirruslabs/flutter:stable AS flutter-web

WORKDIR /workspace/lifeverse_app
COPY lifeverse_app/pubspec.yaml lifeverse_app/pubspec.lock ./
RUN flutter pub get
COPY lifeverse_app/ ./
RUN flutter build web --release --dart-define=API_BASE_URL=/api

FROM node:22-alpine

ENV NODE_ENV=production
ENV WEB_BUILD_DIR=/app/public
WORKDIR /app

COPY lifeverse_backend/package.json lifeverse_backend/package-lock.json ./
RUN npm ci --omit=dev
COPY lifeverse_backend/src ./src
COPY --from=flutter-web /workspace/lifeverse_app/build/web ./public

EXPOSE 3000
CMD ["sh", "-c", "npm run init-db && npm start"]
