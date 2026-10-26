import sys, glob, os
from playwright.sync_api import sync_playwright
import pathlib
OUT=str(pathlib.Path(__file__).resolve().parent/'build')
with sync_playwright() as p:
    b=p.chromium.launch()
    pg=b.new_page(viewport={'width':1123,'height':794})
    pg.goto(f'file://{OUT}/sheets.html'); pg.wait_for_selector('body[data-ready]'); pg.wait_for_timeout(500)
    # PDF из листов, отрисованных в 400 dpi (JPEG 92): ~7 МБ вместо ~27 МБ у векторного —
    # фактуры-фильтры в векторном PDF раздуваются; QR при 400 dpi остаются чёткими
    import io
    from PIL import Image
    big=b.new_page(viewport={'width':1123,'height':794}, device_scale_factor=400/96)
    big.goto(f'file://{OUT}/sheets.html'); big.wait_for_selector('body[data-ready]'); big.wait_for_timeout(500)
    sheets=[Image.open(io.BytesIO(el.screenshot())).convert('RGB') for el in big.query_selector_all('.sheet')]
    sheets[0].save(f'{OUT}/badges_print.pdf', save_all=True, append_images=sheets[1:], resolution=400, quality=92, optimize=True)
    pg.screenshot(path=f'{OUT}/_sheets.png', full_page=True)
    pg2=b.new_page(viewport={'width':350,'height':425}, device_scale_factor=3)
    os.makedirs(f'{OUT}/png',exist_ok=True)
    for f in sorted(glob.glob(f'{OUT}/badge-*.html')):
        slug=f.split('badge-')[1][:-5]
        pg2.goto('file://'+f); pg2.wait_for_selector('body[data-ready]'); pg2.wait_for_timeout(200)
        pg2.screenshot(path=f'{OUT}/png/{slug}.png', omit_background=True)
    b.close()

# JPG-картинки бейджей для панели мастеров + PDF в badges/
from PIL import Image
import shutil
ROOT=pathlib.Path(__file__).resolve().parents[2]
for f in glob.glob(f'{OUT}/png/*.png'):
    im=Image.open(f).convert('RGBA'); bg=Image.new('RGB',im.size,'white'); bg.paste(im,mask=im.split()[3])
    bg.save(ROOT/'badges'/(os.path.basename(f)[:-4]+'.jpg'),quality=88)
shutil.copy(f'{OUT}/badges_print.pdf', ROOT/'badges'/'badges_print.pdf')
shutil.copy(f'{OUT}/heroes_qr.csv', ROOT/'badges'/'heroes_qr.csv')
