# ru_rpg в Docker + OmniRoute, полностью на русском

Короткая инструкция: как поднять игру в контейнере, подключить её к **OmniRoute
(Claude Sonnet 4.5)** и играть **полностью на русском**.

---

## 1. Что это за приложение

`ru_rpg` — это форк AI-RPG: Node.js-сервер, который превращает любую
**OpenAI-совместимую** LLM в сольного гейм-мастера настолки. Веб-интерфейс +
JSON API на порту **7777**. Конфиг читается из `config.yaml` (мерджится поверх
`config.default.yaml`). Картинки сцен — опционально (ComfyUI / NanoGPT / OpenAI).

Внутри клиент LLM абсолютно стандартный: `POST {endpoint}/chat/completions` с
заголовком `Authorization: Bearer <apiKey>`. Поэтому к OmniRoute он цепляется
напрямую, без прослоек.

---

## 2. Файлы, которые добавлены

| Файл | Зачем |
|------|-------|
| `Dockerfile` | образ на `node:20-bookworm-slim` (glibc — чтобы `sharp` работал без сборки) |
| `.dockerignore` | не тащить в образ node_modules, сейвы, логи, .git |
| `docker-compose.yml` | один сервис, проброс порта, тома для сейвов, доступ к OmniRoute на хосте |
| `config.omniroute.yaml` | готовый конфиг: OmniRoute + русский вывод |

Одного контейнера достаточно. Второй контейнер нужен только если захочешь
запускать **OmniRoute тоже в Docker** или поднять **ComfyUI** для картинок
(см. §6).

---

## 3. Запуск (3 шага)

> ⚠️ **Сначала создай `config.yaml`, потом `up`.** Если файла нет, Docker при
> монтировании создаст вместо него *папку* `config.yaml`, и сервер упадёт с
> `Runtime config must contain a YAML object`.

```bash
# 1. конфиг
cp config.omniroute.yaml config.yaml
#    -> открой config.yaml и впиши свой токен в ai.apiKey (sk-f26...)

# 2. собрать и запустить
docker compose up -d --build

# 3. играть
#    открой http://localhost:7777  -> /new-game для новой кампании
```

Логи: `docker compose logs -f ru_rpg`. Остановить: `docker compose down`.
Сейвы/логи/картинки лежат рядом в папках `saves/`, `logs/`, `public/generated-images/`
и переживают пересборку.

---

## 4. Подключение через OmniRoute

Ты обычно коннектишься Claude Code так:

```
set ANTHROPIC_BASE_URL=http://localhost:20128/v1
set ANTHROPIC_AUTH_TOKEN=sk-f26...
set ANTHROPIC_MODEL=kr/claude-sonnet-4.5
```

OmniRoute — это шлюз, который **на одном и том же** `:20128/v1` отдаёт сразу два
формата: Anthropic (`/v1/messages`, его берёт Claude Code) **и OpenAI**
(`/v1/chat/completions`, `/v1/images/generations`, ...). `ru_rpg` — OpenAI-клиент,
поэтому в `config.yaml` указываем именно OpenAI-сторону того же эндпоинта:

```yaml
ai:
  endpoint: "http://host.docker.internal:20128/v1"   # в Docker; вне Docker -> http://localhost:20128/v1
  apiKey:   "sk-f26..."          # это твой ANTHROPIC_AUTH_TOKEN
  model:    "kr/claude-sonnet-4.5"
```

Соответствие переменных:

| OmniRoute / Claude Code | config.yaml (ru_rpg) |
|---|---|
| `ANTHROPIC_BASE_URL` = `http://localhost:20128/v1` | `ai.endpoint` = `http://host.docker.internal:20128/v1` |
| `ANTHROPIC_AUTH_TOKEN` = `sk-f26...` | `ai.apiKey` = `sk-f26...` |
| `ANTHROPIC_MODEL` = `kr/claude-sonnet-4.5` | `ai.model` = `kr/claude-sonnet-4.5` |
| `ANTHROPIC_API_KEY` (пусто) | не используется |

**Почему `host.docker.internal`, а не `localhost`:** внутри контейнера `localhost`
— это сам контейнер. OmniRoute крутится на **хосте**, поэтому в
`docker-compose.yml` проброшено `extra_hosts: host.docker.internal:host-gateway`,
и контейнер достукивается до хоста по этому имени. (Запускаешь без Docker — ставь
`http://localhost:20128/v1`.)

Проверка связи из контейнера:

```bash
docker compose exec ru_rpg node -e "fetch('http://host.docker.internal:20128/v1/models',{headers:{Authorization:'Bearer '+process.env.T}}).then(r=>r.text()).then(t=>console.log(t.slice(0,400)))"
# (T можно не задавать — /v1/models у OmniRoute обычно открыт)
```

---

## 5. Как играть полностью на русском

Три рычага, по нарастанию надёжности:

**(а) Глобальная инструкция языка — уже в `config.omniroute.yaml`.**
Поле `extra_system_instructions` подмешивается в системный промпт всех основных
генераций (проза, проверки событий, генерация регионов/локаций/NPC/предметов/
квестов). Там сказано: весь видимый игроку текст и все имена/названия — на
русском, но **XML-теги, имена полей и перечислимые значения формата оставлять
английскими** (их ждёт парсер). Это ключевой момент — не проси модель переводить
сами теги, иначе сломается разбор ответа.

**(б) Создавай мир на русском.** В `/new-game` опиши сеттинг, жанр, тон и
заметки о стиле по-русски (поля `description` / `genre` / `tone` /
`writingStyleNotes`). Модель зеркалит язык сеттинга — это самый сильный сигнал,
сильнее любой инструкции. Тогда и сгенерированные атрибуты/навыки/имена выйдут
русскими.

**(в) Пиши действия по-русски.** Claude многоязычен и ведёт повествование на
языке игрока.

### Полная локализация листа персонажа (опционально)

Базовые атрибуты и навыки берутся из `defs/attributes.yaml` и
`defs/default_skills.yaml` — там значения по умолчанию **на английском**
(Strength, Dexterity, Perception...). Если хочешь, чтобы и стандартный лист был
русским даже без описания сеттинга, переведи `label`/названия в этих файлах:

```yaml
# defs/attributes.yaml
attributes:
  strength:
    label: Сила
    abbreviation: СИЛ
    description: Мера твоей физической мощи.
```

```yaml
# defs/default_skills.yaml
- Дальний бой
- Ближний бой
- Восприятие
```

> Важно: меняй только человекочитаемые `label`/строки, но **ключи** (`strength`,
> `dexterity` и т.п.) оставляй английскими — на них завязана механика.
> Если сеттинг создаётся с AI на русском, этот шаг обычно не нужен — атрибуты и
> навыки сеттинга перекрывают дефолтные.

### Чего русификация НЕ трогает
Интерфейс (кнопки, вкладки, меню) — это «обвязка» приложения, она остаётся
английской, пока не локализованы шаблоны во `views/`. Это отдельная большая
задача; на само повествование и контент игры не влияет. Если нужен и русский UI —
скажи, прикину объём.

---

## 6. Картинки сцен (по желанию)

`kr/claude-sonnet-4.5` картинки не рисует, поэтому в готовом конфиге
`imagegen.enabled: false` — игра работает чисто на тексте через OmniRoute.
Включить арт можно так:

- **Через OmniRoute (без второго контейнера):** OmniRoute умеет
  `/v1/images/generations`. В `config.yaml`:
  ```yaml
  imagegen:
    enabled: true
    engine: openai
    endpoint: "http://host.docker.internal:20128/v1"
    apiKey: "sk-f26..."
    model: "<image-модель-в-omniroute>"   # например, флукс/qwen-image-алиас
  ```
- **Через NanoGPT:** `engine: nanogpt` + свой `apiKey` от NanoGPT.
- **Локально через ComfyUI:** подними ComfyUI в отдельном контейнере и укажи
  `engine: comfyui`, `server.host`, `server.port`. Тогда это вторая служба в
  `docker-compose.yml` (могу дописать, если решишь так делать).

---

## 7. Типичные грабли

1. **`config.yaml` стал папкой** → ты не создал файл перед `up`. Удали папку,
   сделай `cp config.omniroute.yaml config.yaml`, подними заново.
2. **`ECONNREFUSED host.docker.internal:20128`** → OmniRoute не запущен на хосте
   или слушает только `127.0.0.1` без проброса. Проверь, что шлюз поднят, и что в
   compose есть `extra_hosts: host.docker.internal:host-gateway`.
3. **Ответы на английском** → не задан русский сеттинг (см. §5б) или кто-то
   затёр `extra_system_instructions`. Самый сильный фикс — описать мир по-русски.
4. **Ошибки разбора XML на русском** → не давай модели переводить теги/ключи;
   `strictXMLParsing` оставь `false` (по умолчанию так и есть).
5. **Долгий вход в новый регион** — это нормально: регион и локации
   генерируются заранее, первый вход самый медленный.
6. **Нет прав на запись сейвов (только Linux-хост)** → контейнер пишет от uid
   1000 (`node`). Если папки создались под root: `sudo chown -R 1000:1000 saves
   autosaves logs logs_prev exports lorebooks new-game-settings public/generated-images`.
   На Docker Desktop (Windows/Mac) это не требуется.
