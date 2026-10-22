# Бейджи «Тишина Парадайза» — сборка

Готовое лежит в `badges/` в корне репозитория: `badges_print.pdf` (A4 альбомный, 6 бейджей 70×85 мм на листе),
картинки каждого бейджа `<slug>.jpg` (открываются кнопкой «🪪 Бейдж» в панели мастеров) и `heroes_qr.csv`.

Пересобрать после правок:

```
pip install segno zxing-cpp pillow playwright
python build.py     # собирает build/sheets.html и build/badge-*.html из макета design/
python render.py    # PDF + JPG в ../../badges/
```

- Макет карточек — `design/*.dc.html` (утверждённый, см. HANDOFF.md). Новые персонажи и правки полей — в `HEROES` и `build_card()` в build.py.
- Фото берутся из `catalog/photos/<slug>.jpg` (те же, что в каталоге).
- Новые QR — `make_qr.py` (каждый код проверяется ZXing). Код на бейдже должен совпадать с `qr_code` персонажа в базе — см. `sql/catalog.sql`.
