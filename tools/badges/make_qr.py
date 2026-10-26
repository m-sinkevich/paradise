"""Генерация и проверка цветных QR-кодов для бейджей «Тишина Парадайза».

Установка:  pip install segno zxing-cpp pillow
Запуск:     заполнить список NEW ниже, затем  python make_qr.py
            — появятся qr-<имя>.svg и проверочные _check-<имя>.png, в консоли код и OK/FAIL

Правила (так сделаны все существующие коды):
- содержимое: 6 символов из алфавита без 0/O/1/I;
- коррекция ошибок H, обычный QR версии 1 (21×21). ВАЖНО: micro=False — иначе segno выдаёт Micro QR 17×17,
  который ZXing читает, а телефоны и терминал (jsQR) — нет;
- SVG: scale=10, border=3, прозрачный фон (light=None) — фон даёт белая/светлая плашка на бейдже;
- цвета модулей по модулю колонии (data / угловые квадраты):
    Пирвели     #3B1E0C / #A0501A   плашка #FBF5EA
    Парадайз    #13314F / #1F5A91   плашка #FFFFFF
    Фридом      #5E0B10 / #B31B20   плашка #FFFFFF
    Искупление  #1E1E1E / #000000   плашка #FFF3C4
- каждый код после генерации декодируется через ZXing на плашечном фоне — должно быть OK.
"""
import random
import segno
import zxingcpp
from PIL import Image

ALPHA = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

THEMES = {
    "pirveli":    ("#3B1E0C", "#A0501A", "#FBF5EA"),
    "paradise":   ("#13314F", "#1F5A91", "#FFFFFF"),
    "freedom":    ("#5E0B10", "#B31B20", "#FFFFFF"),
    "redemption": ("#1E1E1E", "#000000", "#FFF3C4"),
}

# Уже выданные коды — новые не должны с ними совпадать
USED = {"MK8XYW", "PN68AC", "YK5V65", "TRD6W3", "WS5NEX", "EYRT3M",
        "PH2GAD", "BN533Q", "FJKTZD", "ZT3H52", "9DQMDT"}

# Заполните: (имя файла латиницей, модуль)
NEW = [
    # ("arsen", "pirveli"),
    # ("silvia", "pirveli"),
    # ("eva", "freedom"),
    # ("ganesh", "freedom"),
    # ("mateo", "redemption"),
]


def make(slug, theme, code=None):
    dark, finder, plate = THEMES[theme]
    rng = random.SystemRandom()
    while code is None or code in USED:
        code = "".join(rng.choice(ALPHA) for _ in range(6))
    USED.add(code)
    q = segno.make(code, error="h", micro=False)   # micro=False: Micro QR не читается телефонами и терминалом (jsQR)
    q.save(f"qr-{slug}.svg", scale=10, border=3, dark=dark, finder_dark=finder, light=None, xmldecl=False)
    q.save(f"_check-{slug}.png", scale=5, border=3, dark=dark, finder_dark=finder, light=plate)
    res = zxingcpp.read_barcodes(Image.open(f"_check-{slug}.png").convert("RGB"))
    ok = bool(res) and res[0].text == code
    print(f"{slug:10s} {theme:11s} {code}  {'OK' if ok else 'FAIL'}")
    return code


if __name__ == "__main__":
    for slug, theme in NEW:
        make(slug, theme)
