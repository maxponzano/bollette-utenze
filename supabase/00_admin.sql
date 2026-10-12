-- Amministratori: vedono e modificano tutti i clienti.
-- Sostituisci l'indirizzo con la TUA email (minuscolo), la stessa che userai per il login.
-- Eseguire DOPO 01_schema.sql.
insert into public.admins (email) values ('la-tua-email@esempio.it')
on conflict (email) do nothing;
