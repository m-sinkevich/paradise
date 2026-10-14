# Техническое задание: «Терминал колониста»
## Информационно-игровая система для LARP «Планета-колония»

Версия 2 — консолидирована по итогам разработки и тестирования MVP.
Статус: рабочий прототип подключён к реальной базе (Supabase), проверен вживую.

---

## 1. Общее описание

Веб-приложение (HTML/JS/CSS, без сборки) — терминал в жилом модуле колонии, запускается в браузере на любом компьютере. Сеть из **5-6 терминалов**, до **20 игроков одновременно**. Один из терминалов дополнительно работает в режиме панели мастера. Общая база данных — Supabase (Postgres + Realtime + Storage), доступ через интернет. Интерфейс — стилизация под панель управления космической станции.

---

## 2. Роли и уровни доступа

| Роль | Способ входа | Права |
|---|---|---|
| **Игрок/персонаж** | Личный QR-код (бейдж) + опционально пароль | Просмотр контента, запись в бортовой журнал, сканирование QR-объектов |
| **Модуль/станция** | `access_code` в таблице `modules` | Определяет локацию и доступный на ней контент |
| **Мастер/НПС** | Отдельный вход на одном из терминалов (спец. режим) | Обзор модулей, отправка событий и тревог, ручное управление контентом |
| **Супер-админ** | Отдельная админка (до/между играми) | Наполнение базы: персонажи, контент, QR-коды |

---

## 3. Основной пользовательский сценарий

1. Экран ожидания (виден всегда, даже без входа) → кнопка «Начать сканирование».
2. Нажатие открывает **модальное окно сканера** (увеличивающийся попап с анимацией масштабирования, без отдельной кнопки «включить камеру» — камера включается сразу при открытии попапа). Внутри — видео с камеры, рамка вокруг распознанного QR-кода, текстовый индикатор «поиск...» / «✓ считано: ...», плюс поле для ручного ввода кода на случай проблем с камерой.
3. После успешного распознавания попап автоматически сворачивается (короткая визуальная вспышка подтверждения) → **аутентификация**.
4. После входа — главное меню:
   - **Бортовой журнал** (запись текстом; голосовая — следующий этап) — с кнопкой возврата в главное меню;
   - **Сканировать объект** — тот же модальный сканер, теперь для QR-кодов предметов/локаций;
   - **Завершить сеанс** — ручной выход в режим ожидания.
5. Контент по QR — текст (посимвольный вывод), видео или аудио, возможна цепочка с одноразовым выбором ветки.
6. Свойство контента **once/unlimited** — при повторном сканировании «одноразового» объекта терминал сообщает, что доступ закрыт.

---

## 4. Сессия игрока

Настраивается индивидуально на персонажа (поля в таблице `characters`):
- **`session_timeout_minutes`** — жёсткий таймер сессии; отображается обратным отсчётом в футере терминала; по истечении терминал автоматически возвращается в режим ожидания аутентификации.
- **`inactivity_timeout_minutes`** — таймер бездействия; сбрасывается любым действием игрока (клик/ввод/тач); по истечении — автоматический выход в режим ожидания.
- Оба таймера — опциональные и независимые, можно задать один, оба или ни одного.
- Кнопка **«Завершить сеанс»** — ручной выход в любой момент.
- Все варианты завершения (таймаут по времени, по бездействию, вручную) фиксируются в `logs` с указанием причины.

---

## 5. Бортовой журнал и «тишина в эфире»

- Запись (пока текст) сохраняется с привязкой к автору, модулю, времени.
- **Таймер бездействия журнала — общий на модуль**: считается от последней записи любым игроком. Настраивается через `modules.silence_timeout_minutes` (по умолчанию 20 минут).
- Реакция на истечение таймера (сирена/смена интерфейса) — реализуется как контент типа `event` с триггером `silence_timeout`. *(Логика запуска — следующий этап.)*
- Экран журнала содержит кнопку возврата в главное меню.

---

## 6. Режим тревоги модуля («Опасный газ снаружи» и подобные)

Отдельный, визуально безошибочно узнаваемый баннер (мигающая диагональная штриховка, красный) — **отображается поверх любого экрана терминала независимо от того, аутентифицирован ли кто-то**.

- Таблица `alerts`: тревога может быть привязана к конкретному модулю (`target_module_id`) или ко всем (`target_type = 'all'`).
- Период действия задаётся **заранее** (`starts_at`/`ends_at` в будущем — сработает по расписанию) **или включается мгновенно командой мастера** (вставка строки с `starts_at = now()`), и снимается либо по истечении `ends_at`, либо явным выключением (`active = false`).
- Терминал проверяет активные тревоги каждые 15 секунд плюс подписан на realtime-обновления таблицы `alerts` — отклик практически мгновенный.
- Реализовано и проверено в MVP.

---

## 7. События от мастера (общая механика, отдельная от тревог)

Мастер отправляет событие: на конкретный модуль / группу / все сразу. Событие — аудио-сирена с голосовым предупреждением, видео на весь экран, смена интерфейса, разблокировка контента.

- `interrupt_behavior: hard` — прерывает текущий контент немедленно.
- `interrupt_behavior: soft` — становится в очередь, запускается после завершения текущего.
- Доставка — realtime-подписка на таблицу `events` (Supabase Publications).

*Статус: таблица и модель данных готовы, обработка на терминале и панель отправки — следующий этап.*

---

## 8. Логика выдачи контента


content_item:
id
trigger_code # QR-код, который его открывает
chain_id, order_index # цепочка и порядок в ней
type: text | audio | video | event
body / media_url
playback: once | unlimited
unlock_condition: {
type: always | after_timer | master_event | player_choice | silence_timeout
timerMinutes / eventId
}
choice_options: [{ id, label, nextContentId }]
requires_previous: [contentId, ...]
interrupt_behavior: hard | soft # для type=event

Реализовано и проверено: `always`, `once/unlimited`, `player_choice` (цепочка с ветвлением, выбор одноразовый).
Не реализовано: `after_timer`, `master_event`, `silence_timeout` — следующий этап.

---

## 9. Панель мастера

- Обзор модулей: статус, последняя активность, текущий контент.
- Отправка событий и тревог — по модулю/группе/всем.
- Просмотр бортовых журналов в реальном времени.
- Ручное открытие/закрытие контента.
- Добавление контента «на лету».

*Статус: не реализовано, следующий этап. Пока тревоги и события тестируются прямой вставкой строк через SQL Editor Supabase.*

---

## 10. Оффлайн-режим и локальный кэш

- **Заранее подготовленный контент** (сюжетные видео/аудио) — хранится локально на диске терминала (папка рядом с `index.html`), путь в поле `media_url`. Раздаётся вручную (флешка/локальная сеть) перед игрой — сознательно не используем облачное файлохранилище для этого (Firebase Storage с февраля 2026 требует платный тариф Blaze даже в рамках бесплатного лимита; Supabase Storage — резерв на будущее для сценариев, где ручная раздача неудобна).
- **Аудиозаписи бортового журнала** (создаются во время игры) — по плану идут через Supabase Storage, т.к. должны быть видны на других терминалах в реальном времени. *(Голосовая запись — не реализована, следующий этап.)*
- Полноценный офлайн-кэш с фоновой синхронизацией через service worker/PWA — следующий этап; в текущем MVP требуется постоянное подключение к Supabase.
- Шифрование локальных данных не требуется («играем на честность»).

---

## 11. Логирование

Таблица `logs` — реализовано: `auth`, `scan`, `content_open`, `content_choice`, `journal_entry`, `session_end` (с причиной: `manual`/`timeout`/`inactivity`). Видно в реальном времени в панели «ЛОГ» терминала (сворачиваемая панель внизу справа, для разработки/отладки).

---

## 12. Интерфейс

Реализовано:
- Палитра: фон `#0A0E16`, панели `#131B2B`, акцент-циан `#5EEAD4`, акцент-янтарь `#FFB454`, красный тревоги `#FF6B6B`.
- Шрифты: `Orbitron` (заголовки/лейблы), `IBM Plex Mono` (основной текст).
- Фирменные элементы: угловые HUD-скобки, сканлайн-эффект, пульсирующий индикатор связи, посимвольный вывод текста, модальное окно сканера с анимацией масштабирования и авто-сворачиванием, баннер тревоги с диагональной штриховкой поверх интерфейса.
- Экраны: ожидание → аутентификация (через модальный сканер) → главное меню → журнал / сканирование объекта → просмотр контента.

Не реализовано: интерфейс панели мастера — следующий этап.

---

## 13. Технологический стек (финальный)

| Компонент | Решение | Причина |
|---|---|---|
| Frontend | HTML/JS/CSS, один файл, без сборки | Просто открыть/раздать на любую ОС |
| БД + realtime + файлы | **Supabase (Postgres + Realtime + Storage)** | Бесплатно без привязки карты; один сервис вместо связки |
| Локальный кэш заранее подготовленного медиа | Файлы на диске терминала | Не тратит лимиты облака |
| Сканирование QR | `jsQR` через `cdn.jsdelivr.net` | Работает в браузере через камеру; `cdnjs.cloudflare.com` оказался нестабилен для этой библиотеки |
| Realtime доставка (тревоги/события) | Supabase Publications (`Database → Publications`) | Push вместо постоянного опроса |
| Хостинг терминала | Локальный веб-сервер на каждом компьютере (`python3 -m http.server`) | `file://` ненадёжен: блокирует/не запоминает доступ к камере, может не грузить внешние скрипты |

---

## 14. Текущий статус реализации

**Готово и проверено вживую:**
- ✅ Аутентификация по QR/паролю через Supabase.
- ✅ Модальный сканер с визуальной обратной связью (рамка, статус-текст), авто-сворачивание после успеха.
- ✅ Сканирование объектов, вывод текста/аудио/видео (медиа — плейсхолдеры до раскладки локальных файлов).
- ✅ Цепочка с одноразовым выбором.
- ✅ Свойство `once`/`unlimited`.
- ✅ Бортовой журнал (текст) с кнопкой возврата в меню.
- ✅ Таймер сессии и таймер бездействия (индивидуально на персонажа), кнопка «Завершить сеанс».
- ✅ Режим тревоги модуля — баннер поверх любого экрана, работает и по расписанию, и по мгновенной команде.
- ✅ Логирование всех ключевых действий.
- ✅ RLS-политики настроены (полный доступ по anon-ключу — соответствует решению «играем на честность»).

**Следующие шаги (в порядке приоритета):**
1. Панель мастера: обзор модулей, отправка событий/тревог из интерфейса (сейчас — через SQL Editor вручную).
2. Условия `after_timer`, `master_event`, `silence_timeout` в `unlock_condition`.
3. Голосовая запись в бортовой журнал (MediaRecorder API) + загрузка в Supabase Storage.
4. Полноценный офлайн-кэш с фоновой синхронизацией (service worker/PWA).
5. Админка контента (таблица + генератор QR-кодов для печати).
6. Выгрузка логов для разбора после игры.
7. Финальная полировка интерфейса, звуковые эффекты.

---

## Приложение А. Схема базы данных (Supabase/Postgres) — актуальная

```sql
create table game_sessions (
  id uuid primary key default gen_random_uuid(),
  name text,
  active boolean default true,
  started_at timestamptz default now(),
  ended_at timestamptz
);

create table modules (
  id uuid primary key default gen_random_uuid(),
  game_session_id uuid references game_sessions(id),
  name text,
  access_code text,
  status text default 'offline',
  last_seen_at timestamptz,
  current_content_id uuid,
  last_journal_entry_at timestamptz,
  silence_timeout_minutes int default 20,
  is_master_terminal boolean default false
);

create table characters (
  id uuid primary key default gen_random_uuid(),
  game_session_id uuid references game_sessions(id),
  name text,
  qr_code text unique,
  password text,
  module_access uuid[],
  active boolean default true,
  session_timeout_minutes int,      -- NEW: жёсткий таймер сессии
  inactivity_timeout_minutes int    -- NEW: таймер бездействия
);

create table content_items (
  id uuid primary key default gen_random_uuid(),
  game_session_id uuid references game_sessions(id),
  trigger_code text,
  chain_id uuid,
  order_index int,
  type text check (type in ('text','audio','video','event')),
  body text,
  media_path text,
  media_url text,
  playback text check (playback in ('once','unlimited')) default 'unlimited',
  module_scope uuid[],
  unlock_condition jsonb,
  choice_options jsonb,
  requires_previous uuid[],
  interrupt_behavior text check (interrupt_behavior in ('hard','soft')),
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  created_by uuid
);

create table character_progress (
  character_id uuid references characters(id),
  content_id uuid references content_items(id),
  play_count int default 0,
  first_opened_at timestamptz,
  last_opened_at timestamptz,
  choice_made uuid,
  primary key (character_id, content_id)
);

create table events (
  id uuid primary key default gen_random_uuid(),
  game_session_id uuid references game_sessions(id),
  content_id uuid references content_items(id),
  target_type text check (target_type in ('module','group','all')),
  target_ids uuid[],
  interrupt_behavior text check (interrupt_behavior in ('hard','soft')),
  created_by uuid,
  created_at timestamptz default now(),
  delivered_to jsonb default '{}'
);

create table journal_entries (
  id uuid primary key default gen_random_uuid(),
  game_session_id uuid references game_sessions(id),
  module_id uuid references modules(id),
  character_id uuid references characters(id),
  type text check (type in ('text','audio')),
  text_content text,
  media_path text,
  created_at timestamptz default now(),
  synced boolean default true
);

create table logs (
  id uuid primary key default gen_random_uuid(),
  game_session_id uuid references game_sessions(id),
  timestamp timestamptz default now(),
  module_id uuid references modules(id),
  character_id uuid references characters(id),
  action_type text,
  details jsonb
);

create table admins (
  id uuid primary key default gen_random_uuid(),
  login text unique,
  password text,
  role text check (role in ('master','superadmin'))
);

-- NEW: режим тревоги модуля
create table alerts (
  id uuid primary key default gen_random_uuid(),
  game_session_id uuid,
  target_type text check (target_type in ('module','all')),
  target_module_id uuid references modules(id),
  label text,
  starts_at timestamptz default now(),
  ends_at timestamptz,
  active boolean default true,
  created_by uuid,
  created_at timestamptz default now()
);
```

**RLS:** включён на всех таблицах, политика «allow all for anon» (полный доступ по публичному ключу):
```sql
alter table <table_name> enable row level security;
create policy "allow all for anon" on <table_name> for all using (true) with check (true);
```
(применено ко всем таблицам, включая `alerts`).

**Realtime:** включается в разделе **Database → Publications** (не «Replication» — в актуальной версии интерфейса Supabase это разные разделы) для таблиц `events`, `journal_entries`, `modules`, `alerts`.

---

## Приложение Б. Практические заметки по развёртыванию

- Открывать терминал **только через `http://localhost:PORT`** (`python3 -m http.server` в папке с файлом), не двойным кликом (`file://`) — иначе не грузятся скрипты и блокируется камера.
- Доступ к камере с IP-адреса в локальной сети (не `localhost`) браузер может посчитать небезопасным контекстом и заблокировать — для сети между разными устройствами понадобится HTTPS.
- CDN для `jsQR` — `cdn.jsdelivr.net` (не `cdnjs.cloudflare.com`, там наблюдались проблемы загрузки).
- Firebase Storage с 3 февраля 2026 требует привязки карты (тариф Blaze) даже в рамках бесплатного лимита — причина перехода на Supabase.
- Supabase бесплатный проект «засыпает» после ~7 дней без обращений — перед игровым днём после паузы зайти в панель и разбудить.
- Демо-данные для тестирования: персонажи `CHAR-001`/`CHAR-002` (пароль у второго — `1234`), объекты `ITEM-LOG-01`, `ITEM-VIDEO-01`, `ITEM-AUDIO-01`, `ITEM-CHAIN-01`.
- Тестирование тревоги и событий, пока нет панели мастера — прямой SQL в Supabase SQL Editor (пример в разделе 6).

---

## Приложение В. Текущий рабочий код

Актуальная реализация — файл `terminal_kolonista_MVP.html` (единый HTML/CSS/JS-файл), включает всё из раздела 14 «Готово». Ключевые модули внутри файла:
- `DB` — слой доступа к Supabase (аутентификация, контент, журнал, логи, прогресс).
- `AlertManager` — опрос и realtime-подписка на тревоги.
- `App` — экраны, сценарии, таймеры сессии, модальный сканер.

Файл передан отдельно в ходе разработки; при необходимости может быть приложен целиком к этому ТЗ как отдельный файл проекта.