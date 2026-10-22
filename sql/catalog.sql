-- =====================================================================
--  КАТАЛОГ ПЕРСОНАЖЕЙ И БЕЙДЖИ: новые поля + данные 16 персонажей
--  Supabase → SQL Editor → выполнить целиком. Можно запускать повторно.
--  QR-коды персонажей становятся такими же, как на напечатанных бейджах.
-- =====================================================================

alter table characters add column if not exists photo_url  text;     -- фото (путь в репозитории или URL)
alter table characters add column if not exists tagline    text;     -- кратко, несколько слов
alter table characters add column if not exists legend     text;     -- общедоступная легенда
alter table characters add column if not exists badge_url  text;     -- картинка бейджа
alter table characters add column if not exists home_module_id uuid references modules(id) on delete set null; -- модуль в каталоге
alter table characters add column if not exists catalog_visible boolean not null default true;
alter table characters add column if not exists catalog_order int;
alter table modules    add column if not exists description   text;  -- описание модуля для каталога
alter table modules    add column if not exists catalog_order int;

do $$
declare
  mid uuid; cid uuid; n int;
begin

  select id into mid from modules where lower(btrim(name)) like 'пирвел%' or lower(name) like '%pirvel%' or lower(access_code) like '%pirvel%' order by name limit 1;
  if mid is null then raise notice 'Модуль «Пирвели» не найден — привяжите персонажей вручную в панели мастеров';
  else update modules set catalog_order = 1, description = coalesce(description, $t$Первый модуль, появившийся на поверхности, он стоит тут уже 4 сол года, жители уже успели освоить базовое сельское хозяйство, и, что самое главное - технологию получения вина из местных культур.$t$) where id = mid; end if;

  select id into mid from modules where lower(btrim(name)) like 'парад%' or lower(name) like '%paradi%' or lower(access_code) like '%paradi%' order by name limit 1;
  if mid is null then raise notice 'Модуль «Парадайз» не найден — привяжите персонажей вручную в панели мастеров';
  else update modules set catalog_order = 2, description = coalesce(description, $t$Учёные Сола сказали, те что телескопами заведуют, что эта планета сказочно красива, и предприниматели, не дождавшись результатов миссии уже продали тур. Модуль оснащен самыми комфортными принадлежностями, но запасы пищи и алкоголя уже давно закончились. И вот 4 миллиардера вынуждены выживать на планете без особых знаний и навыков. Зато у них есть проектор. На поверхности уже 2,5 сол лет.$t$) where id = mid; end if;

  select id into mid from modules where lower(btrim(name)) like 'фридом%' or lower(name) like '%freedom%' or lower(access_code) like '%freedom%' order by name limit 1;
  if mid is null then raise notice 'Модуль «Фридом» не найден — привяжите персонажей вручную в панели мастеров';
  else update modules set catalog_order = 3, description = coalesce(description, $t$Спасательный модуль, направленный на разведку и эвакуацию Парадайса. Единственный колониальный модуль в известной галактике оснащенный вооружением и средствами защиты. Из-за того, что большая часть грузового отсека занята вооружением и спец оборудованием - условия проживания достаточно спартанские. На поверхности 0.5 сол года$t$) where id = mid; end if;

  select id into mid from modules where lower(btrim(name)) like 'искуп%' or lower(name) like '%redemp%' or lower(access_code) like '%redemp%' order by name limit 1;
  if mid is null then raise notice 'Модуль «Искупление» не найден — привяжите персонажей вручную в панели мастеров';
  else update modules set catalog_order = 4, description = coalesce(description, $t$Тюремный модуль, который по каким-то причинам был выкинут не в той части галактики, куда направлялся. Из-за отсутствия топлива на следующий прыжок был вынужден приземлиться на ближайшую пригодную для колонизационного модуля планету. На поверхности 6 сол дней.$t$) where id = mid; end if;


  -- Гиорги Гхвиношвили
  select id into mid from modules where lower(btrim(name)) like 'пирвел%' or lower(name) like '%pirvel%' or lower(access_code) like '%pirvel%' order by name limit 1;
  select id into cid from characters where lower(btrim(name)) in ('гиорги гхвиношвили') order by xmin::text::bigint desc limit 1;
  update characters set qr_code = qr_code || '-OLD' where upper(qr_code) = 'MK8XYW' and id is distinct from cid;
  if cid is null then
    insert into characters (name, qr_code, active, module_access) values ($t$Гиорги Гхвиношвили$t$, 'MK8XYW', true, case when mid is null then null else array[mid] end) returning id into cid;
    raise notice 'Создан: %', $t$Гиорги Гхвиношвили$t$;
  end if;
  update characters set name = $t$Гиорги Гхвиношвили$t$, qr_code = 'MK8XYW', badge_id = coalesce(nullif('PG-CAP-01', ''), badge_id),
    photo_url = 'catalog/photos/giorgi.jpg', badge_url = 'badges/giorgi.jpg',
    tagline = $t$Капитан первой экспедиции, винодел$t$, legend = $t$Глава первой официальной экспедиции на планету, капитан, старый мудрый человек, непосредственно с Земли. Изначально специалист по сельскому хозяйству и ветеринар. Именно он разработал технологию производства вина в этих условиях, хотя Арсен говорит всем, что первое вино было его производства.$t$,
    home_module_id = coalesce(mid, home_module_id), catalog_order = 1,
    module_access = case when mid is null or mid = any(coalesce(module_access, '{}')) then module_access else array_append(coalesce(module_access, '{}'), mid) end
  where id = cid;

  -- Арсен Серосян
  select id into mid from modules where lower(btrim(name)) like 'пирвел%' or lower(name) like '%pirvel%' or lower(access_code) like '%pirvel%' order by name limit 1;
  select id into cid from characters where lower(btrim(name)) in ('арсен серосян') order by xmin::text::bigint desc limit 1;
  update characters set qr_code = qr_code || '-OLD' where upper(qr_code) = 'UNMCH3' and id is distinct from cid;
  if cid is null then
    insert into characters (name, qr_code, active, module_access) values ($t$Арсен Серосян$t$, 'UNMCH3', true, case when mid is null then null else array[mid] end) returning id into cid;
    raise notice 'Создан: %', $t$Арсен Серосян$t$;
  end if;
  update characters set name = $t$Арсен Серосян$t$, qr_code = 'UNMCH3', badge_id = coalesce(nullif('PG-XO-02', ''), badge_id),
    photo_url = 'catalog/photos/arsen.jpg', badge_url = 'badges/arsen.jpg',
    tagline = $t$Старпом, мастер на все руки$t$, legend = $t$Старпом колонизационного корабля а теперь второй человек в модуле, мастер на все руки, но ничего не умеет делать прямо отлично. Родился и вырос на космической станции - это его первая поверхность.$t$,
    home_module_id = coalesce(mid, home_module_id), catalog_order = 2,
    module_access = case when mid is null or mid = any(coalesce(module_access, '{}')) then module_access else array_append(coalesce(module_access, '{}'), mid) end
  where id = cid;

  -- Степан Рязин
  select id into mid from modules where lower(btrim(name)) like 'пирвел%' or lower(name) like '%pirvel%' or lower(access_code) like '%pirvel%' order by name limit 1;
  select id into cid from characters where lower(btrim(name)) in ('степан рязин', 'елена рязина') order by xmin::text::bigint desc limit 1;
  update characters set qr_code = qr_code || '-OLD' where upper(qr_code) = 'PN68AC' and id is distinct from cid;
  if cid is null then
    insert into characters (name, qr_code, active, module_access) values ($t$Степан Рязин$t$, 'PN68AC', true, case when mid is null then null else array[mid] end) returning id into cid;
    raise notice 'Создан: %', $t$Степан Рязин$t$;
  end if;
  update characters set name = $t$Степан Рязин$t$, qr_code = 'PN68AC', badge_id = coalesce(nullif('PG-ENG-03', ''), badge_id),
    photo_url = 'catalog/photos/stepan.jpg', badge_url = 'badges/stepan.jpg',
    tagline = $t$Инженер, без которого миссия бы не выжила$t$, legend = $t$Инженер. Может сделать из грунта и кусков древесины почти все что угодно, миссия выжила скорее всего лишь благодаря ему. Умеет принимать решения в условиях стресса и жутких дедлайнов.$t$,
    home_module_id = coalesce(mid, home_module_id), catalog_order = 3,
    module_access = case when mid is null or mid = any(coalesce(module_access, '{}')) then module_access else array_append(coalesce(module_access, '{}'), mid) end
  where id = cid;

  -- Сильвио Чирзанне
  select id into mid from modules where lower(btrim(name)) like 'пирвел%' or lower(name) like '%pirvel%' or lower(access_code) like '%pirvel%' order by name limit 1;
  select id into cid from characters where lower(btrim(name)) in ('сильвио чирзанне', 'сильвия чирзанне') order by xmin::text::bigint desc limit 1;
  update characters set qr_code = qr_code || '-OLD' where upper(qr_code) = 'VS6YE9' and id is distinct from cid;
  if cid is null then
    insert into characters (name, qr_code, active, module_access) values ($t$Сильвио Чирзанне$t$, 'VS6YE9', true, case when mid is null then null else array[mid] end) returning id into cid;
    raise notice 'Создан: %', $t$Сильвио Чирзанне$t$;
  end if;
  update characters set name = $t$Сильвио Чирзанне$t$, qr_code = 'VS6YE9', badge_id = coalesce(nullif('PG-SCI-04', ''), badge_id),
    photo_url = 'catalog/photos/silvio.jpg', badge_url = 'badges/silvio.jpg',
    tagline = $t$Учёный, которого недооценивают$t$, legend = $t$Ученый. Иногда кажется, что он не присутствует в этом мире, однако впечатления обманчивы. Он просто использует все ресурсы своего мозга, без расточительства, выдает поразительные результаты, хотя никто их не замечает и иногда даже посмеивается. Но все что делают остальные члены команды почти всегда основываются на той базе, что выдает Сильвио. Еще бы научился выражаться не только научными терминами…$t$,
    home_module_id = coalesce(mid, home_module_id), catalog_order = 4,
    module_access = case when mid is null or mid = any(coalesce(module_access, '{}')) then module_access else array_append(coalesce(module_access, '{}'), mid) end
  where id = cid;

  -- Эндрю Воллас
  select id into mid from modules where lower(btrim(name)) like 'парад%' or lower(name) like '%paradi%' or lower(access_code) like '%paradi%' order by name limit 1;
  select id into cid from characters where lower(btrim(name)) in ('эндрю воллас') order by xmin::text::bigint desc limit 1;
  update characters set qr_code = qr_code || '-OLD' where upper(qr_code) = 'YK5V65' and id is distinct from cid;
  if cid is null then
    insert into characters (name, qr_code, active, module_access) values ($t$Эндрю Воллас$t$, 'YK5V65', true, case when mid is null then null else array[mid] end) returning id into cid;
    raise notice 'Создан: %', $t$Эндрю Воллас$t$;
  end if;
  update characters set name = $t$Эндрю Воллас$t$, qr_code = 'YK5V65', badge_id = coalesce(nullif('', ''), badge_id),
    photo_url = 'catalog/photos/andrew.jpg', badge_url = 'badges/andrew.jpg',
    tagline = $t$Страховой магнат и прирождённый лидер$t$, legend = $t$Ранее, владелец сети страховых компаний, ушлый, скользкий, считает себя главным в модуле, ничего не умеет но обладает очень выраженными лидерскими качествами и каким-то образом умудряется делегировать всё, и люди его даже слушаются$t$,
    home_module_id = coalesce(mid, home_module_id), catalog_order = 5,
    module_access = case when mid is null or mid = any(coalesce(module_access, '{}')) then module_access else array_append(coalesce(module_access, '{}'), mid) end
  where id = cid;

  -- Антуан Зиппер
  select id into mid from modules where lower(btrim(name)) like 'парад%' or lower(name) like '%paradi%' or lower(access_code) like '%paradi%' order by name limit 1;
  select id into cid from characters where lower(btrim(name)) in ('антуан зиппер') order by xmin::text::bigint desc limit 1;
  update characters set qr_code = qr_code || '-OLD' where upper(qr_code) = 'WS5NEX' and id is distinct from cid;
  if cid is null then
    insert into characters (name, qr_code, active, module_access) values ($t$Антуан Зиппер$t$, 'WS5NEX', true, case when mid is null then null else array[mid] end) returning id into cid;
    raise notice 'Создан: %', $t$Антуан Зиппер$t$;
  end if;
  update characters set name = $t$Антуан Зиппер$t$, qr_code = 'WS5NEX', badge_id = coalesce(nullif('', ''), badge_id),
    photo_url = 'catalog/photos/antoine.jpg', badge_url = 'badges/antoine.jpg',
    tagline = $t$Изобретатель мгновенной связи$t$, legend = $t$Инженер, который стоял у истоков изобретения мгновенной межпланетной связи, что сделало его сказочно богатым. Его брат занимался всем менеджментом, поэтому Антуан лишь реализовывал проекты, которые ему были по душе. Как и в остальных модулях - выживание без инженера скорее всего было бы невозможно. Гик, задрот, аутист в отношениях.$t$,
    home_module_id = coalesce(mid, home_module_id), catalog_order = 6,
    module_access = case when mid is null or mid = any(coalesce(module_access, '{}')) then module_access else array_append(coalesce(module_access, '{}'), mid) end
  where id = cid;

  -- Магда Берт
  select id into mid from modules where lower(btrim(name)) like 'парад%' or lower(name) like '%paradi%' or lower(access_code) like '%paradi%' order by name limit 1;
  select id into cid from characters where lower(btrim(name)) in ('магда берт') order by xmin::text::bigint desc limit 1;
  update characters set qr_code = qr_code || '-OLD' where upper(qr_code) = 'EYRT3M' and id is distinct from cid;
  if cid is null then
    insert into characters (name, qr_code, active, module_access) values ($t$Магда Берт$t$, 'EYRT3M', true, case when mid is null then null else array[mid] end) returning id into cid;
    raise notice 'Создан: %', $t$Магда Берт$t$;
  end if;
  update characters set name = $t$Магда Берт$t$, qr_code = 'EYRT3M', badge_id = coalesce(nullif('', ''), badge_id),
    photo_url = 'catalog/photos/magda.jpg', badge_url = 'badges/magda.jpg',
    tagline = $t$Звезда кино, вживается в роль$t$, legend = $t$Известная актриса, которой предложили роль в фильме про колонизаторов, и она полетела на эту планету чтобы вжиться в роль. Чтож, вживается. Но надо отдать должное, она действительно старается сделать всё что от нее зависит чтобы улучшить жизнь в модуле.$t$,
    home_module_id = coalesce(mid, home_module_id), catalog_order = 7,
    module_access = case when mid is null or mid = any(coalesce(module_access, '{}')) then module_access else array_append(coalesce(module_access, '{}'), mid) end
  where id = cid;

  -- Алиссия Тёрнер
  select id into mid from modules where lower(btrim(name)) like 'парад%' or lower(name) like '%paradi%' or lower(access_code) like '%paradi%' order by name limit 1;
  select id into cid from characters where lower(btrim(name)) in ('алиссия тёрнер', 'алисия тернер', 'алиссия тернер', 'алисия тёрнер') order by xmin::text::bigint desc limit 1;
  update characters set qr_code = qr_code || '-OLD' where upper(qr_code) = 'TRD6W3' and id is distinct from cid;
  if cid is null then
    insert into characters (name, qr_code, active, module_access) values ($t$Алиссия Тёрнер$t$, 'TRD6W3', true, case when mid is null then null else array[mid] end) returning id into cid;
    raise notice 'Создан: %', $t$Алиссия Тёрнер$t$;
  end if;
  update characters set name = $t$Алиссия Тёрнер$t$, qr_code = 'TRD6W3', badge_id = coalesce(nullif('', ''), badge_id),
    photo_url = 'catalog/photos/alissia.jpg', badge_url = 'badges/alissia.jpg',
    tagline = $t$Наследница миллиардов, психолог$t$, legend = $t$Молодая девушка, которая унаследовала состояние от отца и не знала что ним делать. Хорошие манеры, лучшее образование, психолог. Действительно помогает команде справляться со стрессом.$t$,
    home_module_id = coalesce(mid, home_module_id), catalog_order = 8,
    module_access = case when mid is null or mid = any(coalesce(module_access, '{}')) then module_access else array_append(coalesce(module_access, '{}'), mid) end
  where id = cid;

  -- Дилан Бэтч
  select id into mid from modules where lower(btrim(name)) like 'фридом%' or lower(name) like '%freedom%' or lower(access_code) like '%freedom%' order by name limit 1;
  select id into cid from characters where lower(btrim(name)) in ('дилан бэтч') order by xmin::text::bigint desc limit 1;
  update characters set qr_code = qr_code || '-OLD' where upper(qr_code) = 'PH2GAD' and id is distinct from cid;
  if cid is null then
    insert into characters (name, qr_code, active, module_access) values ($t$Дилан Бэтч$t$, 'PH2GAD', true, case when mid is null then null else array[mid] end) returning id into cid;
    raise notice 'Создан: %', $t$Дилан Бэтч$t$;
  end if;
  update characters set name = $t$Дилан Бэтч$t$, qr_code = 'PH2GAD', badge_id = coalesce(nullif('', ''), badge_id),
    photo_url = 'catalog/photos/dylan.jpg', badge_url = 'badges/dylan.jpg',
    tagline = $t$Полковник, глава спасательной экспедиции$t$, legend = $t$Глава экспидиции, Полковник. Суровый вояка, участвовал во множестве военных операций как между людьми так и с дикой природой на отдаленных планетах. Полковник скорее по выслуге лет, чем за умение управлять людьми. Все время смотрит на Еву для подтверждения своих решений, а та лишь слегка кивает или склоняет голову.$t$,
    home_module_id = coalesce(mid, home_module_id), catalog_order = 9,
    module_access = case when mid is null or mid = any(coalesce(module_access, '{}')) then module_access else array_append(coalesce(module_access, '{}'), mid) end
  where id = cid;

  -- Ева Форманн
  select id into mid from modules where lower(btrim(name)) like 'фридом%' or lower(name) like '%freedom%' or lower(access_code) like '%freedom%' order by name limit 1;
  select id into cid from characters where lower(btrim(name)) in ('ева форманн', 'ева формман', 'ева форман') order by xmin::text::bigint desc limit 1;
  update characters set qr_code = qr_code || '-OLD' where upper(qr_code) = 'QNGDK2' and id is distinct from cid;
  if cid is null then
    insert into characters (name, qr_code, active, module_access) values ($t$Ева Форманн$t$, 'QNGDK2', true, case when mid is null then null else array[mid] end) returning id into cid;
    raise notice 'Создан: %', $t$Ева Форманн$t$;
  end if;
  update characters set name = $t$Ева Форманн$t$, qr_code = 'QNGDK2', badge_id = coalesce(nullif('', ''), badge_id),
    photo_url = 'catalog/photos/eva.jpg', badge_url = 'badges/eva.jpg',
    tagline = $t$Спецагент из штаба Сола$t$, legend = $t$Спецагент, старается не отсвечивать, но все понимают что именно она тут главная. У нее в карманах множество гаджетов для различных ситуаций, а что у нее за оружие не понимает даже Полковник Бэтч. Большую часть времени проводила в штабе на Соле, но и экспедиций в послужном списке хватает.$t$,
    home_module_id = coalesce(mid, home_module_id), catalog_order = 10,
    module_access = case when mid is null or mid = any(coalesce(module_access, '{}')) then module_access else array_append(coalesce(module_access, '{}'), mid) end
  where id = cid;

  -- Нателла Исайро
  select id into mid from modules where lower(btrim(name)) like 'фридом%' or lower(name) like '%freedom%' or lower(access_code) like '%freedom%' order by name limit 1;
  select id into cid from characters where lower(btrim(name)) in ('нателла исайро', 'нателло исайро') order by xmin::text::bigint desc limit 1;
  update characters set qr_code = qr_code || '-OLD' where upper(qr_code) = 'BN533Q' and id is distinct from cid;
  if cid is null then
    insert into characters (name, qr_code, active, module_access) values ($t$Нателла Исайро$t$, 'BN533Q', true, case when mid is null then null else array[mid] end) returning id into cid;
    raise notice 'Создан: %', $t$Нателла Исайро$t$;
  end if;
  update characters set name = $t$Нателла Исайро$t$, qr_code = 'BN533Q', badge_id = coalesce(nullif('', ''), badge_id),
    photo_url = 'catalog/photos/natella.jpg', badge_url = 'badges/natella.jpg',
    tagline = $t$Фронтовой медик$t$, legend = $t$Медик, но не тот который в тылу, а настоящий, фронтовой. Нателла может вытащить раненого с поля боя и без жалости добить безнадежного, проведя триаж прямо в гуще событий. Знает всё о современных медикаментах, и благо именно модуль Фридом напичкан всем необходимым для того, чтобы добивать приходилось реже. Знает многое о болезнях, ядах и токсинах разных планет.$t$,
    home_module_id = coalesce(mid, home_module_id), catalog_order = 11,
    module_access = case when mid is null or mid = any(coalesce(module_access, '{}')) then module_access else array_append(coalesce(module_access, '{}'), mid) end
  where id = cid;

  -- Ганеш Шарма
  select id into mid from modules where lower(btrim(name)) like 'фридом%' or lower(name) like '%freedom%' or lower(access_code) like '%freedom%' order by name limit 1;
  select id into cid from characters where lower(btrim(name)) in ('ганеш шарма') order by xmin::text::bigint desc limit 1;
  update characters set qr_code = qr_code || '-OLD' where upper(qr_code) = '9KH93X' and id is distinct from cid;
  if cid is null then
    insert into characters (name, qr_code, active, module_access) values ($t$Ганеш Шарма$t$, '9KH93X', true, case when mid is null then null else array[mid] end) returning id into cid;
    raise notice 'Создан: %', $t$Ганеш Шарма$t$;
  end if;
  update characters set name = $t$Ганеш Шарма$t$, qr_code = '9KH93X', badge_id = coalesce(nullif('', ''), badge_id),
    photo_url = 'catalog/photos/ganesh.jpg', badge_url = 'badges/ganesh.jpg',
    tagline = $t$Ксенобиолог, ветеран экспедиций$t$, legend = $t$Ксенобиолог. Правительство предполагает, что проблема может быть не технического характера, поэтому в команде был отправлен Ганеш. Несмотря на его сильный акцент, Ганеш является наверное самым образованным членом команды, участвовал в десятках экспедиций на планеты с неизвестными формами жизни. Считает что разумные формы жизни не могут существовать без круговорота сансары, который происходит только с человеческой расой.$t$,
    home_module_id = coalesce(mid, home_module_id), catalog_order = 12,
    module_access = case when mid is null or mid = any(coalesce(module_access, '{}')) then module_access else array_append(coalesce(module_access, '{}'), mid) end
  where id = cid;

  -- Отец Матео Альварес
  select id into mid from modules where lower(btrim(name)) like 'искуп%' or lower(name) like '%redemp%' or lower(access_code) like '%redemp%' order by name limit 1;
  select id into cid from characters where lower(btrim(name)) in ('отец матео альварес', 'матео альварес', 'отец матео') order by xmin::text::bigint desc limit 1;
  update characters set qr_code = qr_code || '-OLD' where upper(qr_code) = '22HUJR' and id is distinct from cid;
  if cid is null then
    insert into characters (name, qr_code, active, module_access) values ($t$Отец Матео Альварес$t$, '22HUJR', true, case when mid is null then null else array[mid] end) returning id into cid;
    raise notice 'Создан: %', $t$Отец Матео Альварес$t$;
  end if;
  update characters set name = $t$Отец Матео Альварес$t$, qr_code = '22HUJR', badge_id = coalesce(nullif('CH-0020', ''), badge_id),
    photo_url = 'catalog/photos/mateo.jpg', badge_url = 'badges/mateo.jpg',
    tagline = $t$Капеллан, двадцать лет с заключёнными$t$, legend = $t$Капеллан, работает с заключенными более 20 лет. Он не лезет в политику, судебную систему и причины, почему тот или иной человек оказался в заключении, а лишь пытается найти свет в их душах и направить в нужное русло. Имеет огромные связи, поскольку помог пережить каторжные тяготы многим сильным мира сего, но что значат его связи когда нет связи?$t$,
    home_module_id = coalesce(mid, home_module_id), catalog_order = 13,
    module_access = case when mid is null or mid = any(coalesce(module_access, '{}')) then module_access else array_append(coalesce(module_access, '{}'), mid) end
  where id = cid;

  -- Маркус Кейн
  select id into mid from modules where lower(btrim(name)) like 'искуп%' or lower(name) like '%redemp%' or lower(access_code) like '%redemp%' order by name limit 1;
  select id into cid from characters where lower(btrim(name)) in ('маркус кейн') order by xmin::text::bigint desc limit 1;
  update characters set qr_code = qr_code || '-OLD' where upper(qr_code) = 'ZT3H52' and id is distinct from cid;
  if cid is null then
    insert into characters (name, qr_code, active, module_access) values ($t$Маркус Кейн$t$, 'ZT3H52', true, case when mid is null then null else array[mid] end) returning id into cid;
    raise notice 'Создан: %', $t$Маркус Кейн$t$;
  end if;
  update characters set name = $t$Маркус Кейн$t$, qr_code = 'ZT3H52', badge_id = coalesce(nullif('RK-4592-B', ''), badge_id),
    photo_url = 'catalog/photos/marcus.jpg', badge_url = 'badges/marcus.jpg',
    tagline = $t$Бывший капитан милиции, 35 лет каторги$t$, legend = $t$Осужден за превышение служебных полномочий, бывший капитан милиции в одной из колоний, отдал приказ на уничтожение шахты когда там зародился мятеж. Шахты, которая добывала минерал необходимый для создания оружия массового уничтожения (планетарного масштаба), единственной исследованной в галактике. Приговорен к 35 годам на каторге в отдаленном секторе.$t$,
    home_module_id = coalesce(mid, home_module_id), catalog_order = 14,
    module_access = case when mid is null or mid = any(coalesce(module_access, '{}')) then module_access else array_append(coalesce(module_access, '{}'), mid) end
  where id = cid;

  -- Линь Цзинь
  select id into mid from modules where lower(btrim(name)) like 'искуп%' or lower(name) like '%redemp%' or lower(access_code) like '%redemp%' order by name limit 1;
  select id into cid from characters where lower(btrim(name)) in ('линь цзинь') order by xmin::text::bigint desc limit 1;
  update characters set qr_code = qr_code || '-OLD' where upper(qr_code) = '9DQMDT' and id is distinct from cid;
  if cid is null then
    insert into characters (name, qr_code, active, module_access) values ($t$Линь Цзинь$t$, '9DQMDT', true, case when mid is null then null else array[mid] end) returning id into cid;
    raise notice 'Создан: %', $t$Линь Цзинь$t$;
  end if;
  update characters set name = $t$Линь Цзинь$t$, qr_code = '9DQMDT', badge_id = coalesce(nullif('C-1187', ''), badge_id),
    photo_url = 'catalog/photos/lin.jpg', badge_url = 'badges/lin.jpg',
    tagline = $t$Хакер: преступница или героиня?$t$, legend = $t$Осуждена за финансовые махинации, отмывание денег, взлом крупнейших банков. В оппозиционных новостях освещается как героиня, вскрывшая коррупционные схемы правительства, причем в один день в разных системах. До обвинения - специалист по компьютерной безопасности при правительстве Сола.$t$,
    home_module_id = coalesce(mid, home_module_id), catalog_order = 15,
    module_access = case when mid is null or mid = any(coalesce(module_access, '{}')) then module_access else array_append(coalesce(module_access, '{}'), mid) end
  where id = cid;

  -- Тамара Орлова
  select id into mid from modules where lower(btrim(name)) like 'искуп%' or lower(name) like '%redemp%' or lower(access_code) like '%redemp%' order by name limit 1;
  select id into cid from characters where lower(btrim(name)) in ('тамара орлова') order by xmin::text::bigint desc limit 1;
  update characters set qr_code = qr_code || '-OLD' where upper(qr_code) = 'FJKTZD' and id is distinct from cid;
  if cid is null then
    insert into characters (name, qr_code, active, module_access) values ($t$Тамара Орлова$t$, 'FJKTZD', true, case when mid is null then null else array[mid] end) returning id into cid;
    raise notice 'Создан: %', $t$Тамара Орлова$t$;
  end if;
  update characters set name = $t$Тамара Орлова$t$, qr_code = 'FJKTZD', badge_id = coalesce(nullif('A-7324', ''), badge_id),
    photo_url = 'catalog/photos/tamara.jpg', badge_url = 'badges/tamara.jpg',
    tagline = $t$Осуждена за гибель крейсера «Филадельфия»$t$, legend = $t$Осуждена за терроризм и измену правительству Сола. Неоднократно выступала за снижение власти Сола в уже развитых колониях, повышения уровня их автономности. Однако пол года назад была осуждена за взрыв крейсера “Филадельфия” в системе Бетельгейзе. “Филадельфия” была отправлена на устранение мятежа и сепаратистских настроений на Бетельгейзе 2-1 (луна, пригодная для жизни и богатая как органическими так и минеральными ресурсами).$t$,
    home_module_id = coalesce(mid, home_module_id), catalog_order = 16,
    module_access = case when mid is null or mid = any(coalesce(module_access, '{}')) then module_access else array_append(coalesce(module_access, '{}'), mid) end
  where id = cid;

end $$;

-- Проверка: 16 строк, у всех есть модуль и QR как на бейдже
select c.name, c.qr_code, c.badge_id, m.name as module, c.tagline
from characters c left join modules m on m.id = c.home_module_id
where c.photo_url like 'catalog/photos/%' order by c.catalog_order;
