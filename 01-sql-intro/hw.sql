-- ============================================================
-- Домашнее задание к лекции «SQL. Введение»
-- Школа Аналитиков · учебная база hh_school
-- Автор: Кобелев Илья Алексеевич
-- ============================================================
-- Формат: задания по порядку, каждое начинается с комментария
-- с номером; под каждым запросом — вывод (2–3 предложения).
-- Запрос без вывода не засчитывается.
-- ============================================================

SET search_path TO hh_school;


-- ============================================================
-- БЛОК А. Разминка: термины и структура (текстом)
-- ============================================================

-- ЗАДАНИЕ А1
-- 1. Категория и конкретный тип колонок:
--    vacancies.salary_from        — категория: Числовые      тип: INTEGER
--    vacancies.vacancy_name       — категория: Строковые     тип: TEXT
--    vacancies.published_at       — категория: Дата и время  тип: TIMESTAMP
--    employers.is_accredited_it   — категория: Логические    тип: BOOLEAN
--    responses.created_at         — категория: Дата и время  тип: TIMESTAMP
--
-- 2. Первичные ключи таблиц:
--    areas: area_id
--    employers: employer_id
--    vacancies: vacancy_id
--    vacancy_details: vacancy_id (чем особенный: тот же, что и у vacancies vacancy_id (FK))
--    responses: response_id
-- Я слышал, что PK лучше называть просто id, чтобы не было тавтологии
--
-- 3. Почему vacancy_name не может быть первичным ключом:
--    Потому что vacancy_name не уникален и может повторяться, а первичный ключ - это то, что гарантирует уникальность записи
--    Запрос для подтверждения числом:

-- запрос:
SELECT COUNT(DISTINCT vacancy_name), COUNT(vacancy_name)
FROM vacancies;

-- Вывод:
-- 18 уникальных записей, а всего 52, то есть названия вакансий дублируются
--
-- 4. Что произойдёт при записи строки «по договорённости» в salary_from:
--    Ошибка, потому что salary_from имеет тип INTEGER


-- ============================================================
-- БЛОК Б. Первые запросы: SELECT, WHERE, ORDER BY
-- ============================================================

-- ЗАДАНИЕ Б1
-- Запрос: experience
SELECT DISTINCT experience
FROM vacancies
LIMIT 100;

-- Запрос: employment
SELECT DISTINCT employment
FROM vacancies
LIMIT 100;

-- Запрос: professional_role
SELECT DISTINCT professional_role
FROM vacancies
LIMIT 100;

-- Вывод:
-- Мы изучили возможные значения строк в наших таблицах. Теперь мы знаем, что использовать в наших запросах
--


-- ЗАДАНИЕ Б2
-- Запрос 1: стажировки в Москве без опыта, вакансия открыта
SELECT vacancy_name, professional_role, vacancy_id, employer_id
FROM vacancies v
JOIN areas a ON a.area_id = v.area_id
WHERE employment = 'Стажировка' AND experience = 'Нет опыта' AND closed_at IS NULL AND a.area_name = 'Москва'
LIMIT 100;

-- Запрос 2: топ-10 вакансий по salary_from
SELECT COUNT(DISTINCT currency)
FROM vacancies; -- У нас всего 1 валюта в нашей таблице, поэтому нигде в будущем нет проверки на валюты

SELECT *
FROM vacancies
WHERE salary_from IS NOT NULL
ORDER BY salary_from DESC
LIMIT 10;

-- Вывод:
-- В первом запросе мы получили 8 строк вакансий, которые подходят нашим условиям. Среди них большинство аналитиков
-- Во втором запросе мы получили топ 10 вакансий по начальной зарплате. При чем мы не рассматривали вакансии,
--  у которых начальная зарплата не указана


-- ЗАДАНИЕ Б3
-- Ловушка 1. NULL — выполнить и объяснить результат
SELECT count(*) FROM vacancies WHERE closed_at = NULL;
SELECT count(*) FROM vacancies WHERE closed_at IS NULL;
SELECT 1 = NULL, 1 IS NULL, NULL IS NULL;

-- Ловушка 2. AND / OR — выполнить и объяснить результат
SELECT count(*) FROM vacancies
WHERE area_id = 1 OR area_id = 2 AND experience = 'Нет опыта';

SELECT count(*) FROM vacancies
WHERE (area_id = 1 OR area_id = 2) AND experience = 'Нет опыта';

-- Вывод:
-- В первых запросах оператор = вместе с NULL возвращает NULL, а не то, что мы ожидаем уивдеть true или false,
--  поэтому where работает неправильно
-- Во вторых запросах оператор AND выполняется раньше, чем оператор OR, если мы не используем скобочки


-- ============================================================
-- БЛОК В. Агрегации и метрики
-- ============================================================

-- ЗАДАНИЕ В1
-- Запрос 1: счётчики (строки, зарплата указана, направления, работодатели)
SELECT 
    COUNT(*) AS "Строки", 
    COUNT(DISTINCT professional_role) AS "Роли (направления)",
    COUNT(DISTINCT employer_id) AS "Работодатели"
FROM vacancies;

SELECT 
    COUNT(CASE 
        WHEN salary_from IS NOT NULL AND salary_to IS NOT NULL
        THEN 1  
    END) AS "Зарплата вообще не указана",
    COUNT(CASE 
        WHEN salary_from IS NOT NULL AND salary_to IS NULL
        THEN 1  
    END) AS "Только минимальная зарплата",
    COUNT(CASE 
        WHEN salary_from IS NULL AND salary_to IS NOT NULL
        THEN 1  
    END) AS "Только максимальная зарплата",
    COUNT(CASE 
        WHEN salary_from IS NULL AND salary_to IS NULL
        THEN 1  
    END) AS "Диапазон зарплаты указан"
FROM vacancies;

SELECT professional_role, COUNT(professional_role) AS "Количество вакансий"
FROM vacancies
GROUP BY professional_role
LIMIT 100;

SELECT e.employer_name, COUNT(e.employer_id) AS "Количество вакансий", e.employer_id
FROM vacancies v
LEFT JOIN employers e ON e.employer_id = v.employer_id
GROUP BY e.employer_id
LIMIT 100;

-- Запрос 2: доля активных вакансий (без JOIN)
SELECT 
COUNT(*) AS "Всего",
COUNT(closed_at) AS "Закрытые",
ROUND((COUNT(closed_at)::NUMERIC / COUNT(*)), 4) AS "Доля"
FROM vacancies;

-- Вывод:
-- Мы сделали запросы, которые позволяют нам узнать о том, какие данные есть в таблицах и сколько их
--


-- ЗАДАНИЕ В2
-- Запрос 1: направления — вакансии, работодатели, средняя зарплата
SELECT 
    professional_role,
    COUNT(*) AS "Количество вакансий",
    ROUND(AVG((salary_from + salary_to) / 2)) AS "Средняя зарплата",
    COUNT(DISTINCT employer_id) AS "Количество работодателей"
FROM vacancies
GROUP BY professional_role
LIMIT 100;

SELECT 
    e.employer_name,
    COUNT(*) AS "Количество вакансий",
    COUNT(DISTINCT professional_role) AS "Количество направлений",
    e.employer_id
FROM vacancies v
LEFT JOIN employers e ON e.employer_id = v.employer_id
GROUP BY e.employer_id
LIMIT 100;

-- Запрос 2: то же, только направления с ≥ 5 открытыми вакансиями (WHERE + HAVING)
SELECT 
    professional_role,
    COUNT(*) AS "Количество вакансий",
    ROUND(AVG((salary_from + salary_to) / 2)) AS "Средняя зарплата",
    COUNT(DISTINCT employer_id) AS "Количество работодателей"
FROM vacancies
GROUP BY professional_role
HAVING COUNT(professional_role) >= 5
LIMIT 100;

-- Вывод:
-- Мы изучили вакансси по направлениям. Все направления имеют хотя бы 5 открытых вакансий
--


-- ============================================================
-- БЛОК Г. Соединение таблиц
-- ============================================================

-- ЗАДАНИЕ Г1
-- Запрос: топ-5 по salary_from с названием компании и городом (псевдонимы таблиц)
SELECT v.professional_role, v.vacancy_name, v.salary_from, e.employer_name, a.area_name, v.vacancy_id
FROM vacancies v
LEFT JOIN employers e ON e.employer_id = v.employer_id
LEFT JOIN areas a ON a.area_id = v.area_id
WHERE salary_from IS NOT NULL
ORDER BY salary_from DESC
LIMIT 5;
-- Вывод:
-- Мы получили топ 5 вакансий по salary_from. Отсеяли, где NULL
--


-- ЗАДАНИЕ Г2
-- Запрос 1: все работодатели, число вакансий и откликов (LEFT JOIN)
SELECT COUNT(DISTINCT e.employer_id) AS "Работодатели", COUNT(DISTINCT v.vacancy_id) AS "Вакансии", COUNT(DISTINCT r.response_id) AS "Заявки"
FROM employers e
LEFT JOIN vacancies v ON v.employer_id = e.employer_id
LEFT JOIN responses r ON r.vacancy_id = v.vacancy_id;

-- Запрос 2: тот же запрос с INNER JOIN
SELECT COUNT(DISTINCT e.employer_id) AS "Работодатели", COUNT(DISTINCT v.vacancy_id) AS "Вакансии", COUNT(DISTINCT r.response_id) AS "Заявки"
FROM employers e
INNER JOIN vacancies v ON v.employer_id = e.employer_id
INNER JOIN responses r ON r.vacancy_id = v.vacancy_id;

-- Вывод:
-- В первом запросе мы получили всех работодателей. даже тех, у кого нет вакансий (они есть у всех) и тех,
--  у кого нет заявок на вакансии. И все вакансси, даже если они не имеют откликов.
-- Во втором случае мы получили только тех работодателей, у которых есть хотя бы одна вакансия, которая
--  имеет хотя бы один отклик. И только те вакансии, которые имеют хотя бы один отклик.


-- ============================================================
-- БЛОК Д. Функции и финальный кейс
-- ============================================================

-- ЗАДАНИЕ Д1
-- Запрос: помесячная динамика откликов и конверсия
-- (месяц как дата, условный агрегат, nullif в знаменателе)

SELECT 
    date_trunc('month', created_at) AS "month",
    COUNT(*) AS "Количество",
    ROUND(
        COUNT(response_id) FILTER (WHERE status = 'invited')
         / NULLIF(COUNT(*), 0)::NUMERIC, 3
    ) AS "Доля приглашенных от всех"
FROM responses
GROUP BY month
ORDER BY month;

-- Вывод:
-- Мы видим динамику по количеству откликов на все вакансии по месяцам и видим долю приглашенных от всех откликов
--


-- ЗАДАНИЕ Д2
-- Запрос: таблица по направлениям (вакансии, отклики, приглашения,
-- откликов на вакансию, конверсия)
SELECT 
    v.professional_role,
    COUNT(DISTINCT v.vacancy_id) AS vacancies,
    COUNT(r.response_id) AS responses,
    COUNT(r.response_id) FILTER (WHERE r.status = 'invited') AS "Приглашения",
    ROUND(
        COUNT(r.response_id)::numeric / NULLIF(COUNT(DISTINCT v.vacancy_id), 0), 
        2
    ) AS responses_per_vacancy,
    ROUND(
        COUNT(response_id) FILTER (WHERE r.status = 'invited')
         / NULLIF(COUNT(*), 0)::NUMERIC, 3
    ) AS "Конверсия"
FROM vacancies v
LEFT JOIN responses r ON v.vacancy_id = r.vacancy_id
GROUP BY v.professional_role
ORDER BY vacancies DESC;


-- Письменные ответы:
-- 1. Совпадает ли направление с наибольшим числом вакансий с направлением
--    с наибольшей конверсией?
-- Нет, не совпадают

-- 2. Какое направление выбрать и почему (опираясь на два столбца):
-- Тестировщик выглядит как наиболее удачный вариант, потому что у него наибольшая конверсия и
--  запросов на вакансию не так много, то есть низкая конкуренция

-- 3. Оговорка к выводу:
-- У нас очень небольшая выборка данных, поэтому выбросы сильно влияют на наши показатели. 
-- Вакансий на тестировзиков меньше, чем некоторых остальных.
-- Нам скорее нужно смотреть на текущие открытые вакансии и отклики на них и на работодателя


-- ============================================================
-- БЛОК Е. Со звёздочкой
-- ============================================================

-- ЗАДАНИЕ Е1
-- Исходный запрос (выполнить и посмотреть результат):
-- SELECT v.professional_role,
-- count(*) AS vacancies,
-- sum(v.salary_from) AS total_salary,
-- count(r.response_id) / count(*) AS responses_per_vacancy
-- FROM vacancies v
-- JOIN responses r ON v.vacancy_id = r.vacancy_id
-- WHERE v.closed_at = NULL
-- GROUP BY 1;
--
-- Ошибки (минимум четыре):
-- 1. Проверка на NULL с помощью оператора сравнения "="
-- 2. Используется не JOIN без LEFT (равносильно INNER), что выбрасывает вакансии без откликов
-- 3. Неправильный подсчет количества откликов на вакансию + отсутствие NULLIF при делении
-- 4. Неправильный расчет зарплаты: если мы хотим получить среднюю зарплату по этим направлениям, то нам нужно
--  брать среднее (или по распределению, если у нас есть данные) между salary_from и salary_to и брать среднее
--  от них. А считать сумму минимальных зарплат по направлению как будто не имеет смысла без доп группировок
--
-- Вообще как будто это задание можно решить по разному в зависимости от того, что хотел автор
-- В некоторых заданиях просто не совсем понятно, что нужно делать
--
-- Исправленный запрос:
SELECT v.professional_role,
count(*) AS vacancies,
round(avg((salary_from + salary_to) / 2)) AS "Средняя зарплата",
round(
    count(r.response_id)::NUMERIC 
    / nullif(count(DISTINCT v.vacancy_id), 0), 
    2) AS responses_per_vacancy
FROM vacancies v
LEFT JOIN responses r ON v.vacancy_id = r.vacancy_id
WHERE v.closed_at IS NULL
GROUP BY 1;

-- Какие два правила из лекции защитили бы от этих ошибок при написании запроса:
-- 1. Нужно продумывать то, что мы хотим получить, потом, как мы хотим получить
-- 2. Нужно следить за гранулярностью
-- + думоть