# ru_rpg — AI RPG (Node.js) в контейнере
# Базовый образ на glibc (Debian), чтобы prebuilt-бинарь `sharp` работал без сборки libvips.
FROM node:20-bookworm-slim

# Небольшой init для корректной обработки сигналов (Ctrl+C / docker stop)
RUN apt-get update \
    && apt-get install -y --no-install-recommends tini ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ENV NODE_ENV=production
WORKDIR /app

# 1) Сначала только манифест — кешируем слой с зависимостями
COPY package.json ./
# package-lock.json в этом репо в .gitignore, поэтому ставим через install (не ci).
RUN npm install --omit=dev --no-audit --no-fund

# 2) Затем исходники приложения
COPY . .

# 3) Каталоги для сохранений/логов/картинок (на них будут монтироваться тома)
RUN mkdir -p saves autosaves logs logs_prev exports public/generated-images lorebooks new-game-settings \
    && chown -R node:node /app

USER node
EXPOSE 7777

# Сервер сам читает config.yaml (мердж поверх config.default.yaml) и слушает 0.0.0.0:7777
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["node", "server.js", "--port", "7777"]
