-- =====================================================================
--  УДАЛЕНИЕ СНИМКОВ КАМЕРЫ ИЗ ТЕРМИНАЛА МАСТЕРА
--  Supabase → SQL Editor → вставить целиком → Run. Повторный запуск безопасен.
--  Разрешает удалять файлы только из папки photos/ хранилища content-media
--  (туда терминалы складывают снимки). Остальные файлы удалять по-прежнему нельзя.
-- =====================================================================
drop policy if exists "anon delete camera photos" on storage.objects;
create policy "anon delete camera photos" on storage.objects for delete to anon
  using (bucket_id = 'content-media' and name like 'photos/%');
