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
--    vacancy_details: vacancy_id (тут он одновременно PK и FK на vacancies.vacancy_id,
--      то есть связь 1:1, у вакансии только одно описание)
--    responses: response_id
-- Я слышал, что PK лучше называть просто id, чтобы не было тавтологии
--
-- 3. Почему vacancy_name не может быть первичным ключом:
--    Потому что vacancy_name не уникален и может повторяться, а первичный ключ - это то, что гарантирует уникальность записи
--    Запрос для подтверждения числом:

-- запрос:
SELECT COUNT(DISTINCT vacancy_name) AS "Уникальных названий", COUNT(vacancy_name) AS "Всего вакансий"
FROM vacancies;

SELECT vacancy_name, COUNT(*) AS "Сколько раз встречается"
FROM vacancies
GROUP BY vacancy_name
ORDER BY "Сколько раз встречается" DESC
LIMIT 1;

-- Вывод:
-- Самое частое название - "Стажер: аналитик данных", встречается 6 раз из 52 вакансий
-- Уникальных названий 18, то есть названия повторяются, а ключ должен быть уникальным.
-- Поэтому vacancy_name не подходит.
--
-- 4. Что произойдёт при записи строки «по договорённости» в salary_from:
--    Ошибка, потому что salary_from имеет тип INTEGER.
--    Это хорошо, потому что база не даст записать текст в числовую колонку, ошибка вылезет сразу при вставке,
--    а не при подсчетах. Так проще следить за качеством данных.

-- ============================================================
-- БЛОК Б. Первые запросы: SELECT, WHERE, ORDER BY
-- ============================================================

-- ЗАДАНИЕ Б1
-- Запрос: experience
SELECT DISTINCT experience FROM vacancies LIMIT 100;

-- Запрос: employment
SELECT DISTINCT employment FROM vacancies LIMIT 100;

-- Запрос: professional_role
SELECT DISTINCT professional_role FROM vacancies LIMIT 100;

-- Посмотрим, сколько разных значений в каждой колонке и нет ли NULL:
SELECT
    COUNT(*) AS "Всего строк",
    COUNT(experience) AS "experience заполнено",
    COUNT(employment) AS "employment заполнено",
    COUNT(professional_role) AS "professional_role заполнено"
FROM vacancies;

-- Вывод:
-- В experience 3 разных значения, в employment тоже 3, в professional_role 5.
-- Заполнены все 52 строки, пустых значений нет.
-- Одних и тех же значений, записанных по-разному, тоже не нашел - колонки аккуратные.

-- ЗАДАНИЕ Б2
-- Запрос 1: стажировки в Москве без опыта, вакансия открыта
SELECT
    v.vacancy_id,
    v.vacancy_name,
    v.salary_from,
    v.published_at
FROM vacancies v
    JOIN areas a ON a.area_id = v.area_id
WHERE
    v.employment = 'Стажировка'
    AND v.experience = 'Нет опыта'
    AND v.closed_at IS NULL
    AND a.area_name = 'Москва'
ORDER BY v.published_at DESC
LIMIT 100;

-- Запрос 2: топ-10 вакансий по salary_from
SELECT COUNT(DISTINCT currency) FROM vacancies;
-- У нас всего 1 валюта в нашей таблице, поэтому нигде в будущем нет проверки на валюты

SELECT vacancy_name, professional_role, salary_from
FROM vacancies
WHERE
    salary_from IS NOT NULL
ORDER BY salary_from DESC
LIMIT 10;

-- Вывод:
-- Первый запрос нашел 8 открытых стажировок без опыта в Москве.
-- Если убрать условие про Москву, таких вакансий станет 10: добавятся Питер и Екатеринбург.
-- Во втором запросе мы получили топ 10 вакансий по начальной зарплате (игнорировали NULL).

-- ЗАДАНИЕ Б3
-- Ловушка 1. NULL — выполнить и объяснить результат
-- SELECT count(*) FROM vacancies WHERE closed_at = NULL;

SELECT count(*) FROM vacancies WHERE closed_at IS NULL;

SELECT 1 = NULL, 1 IS NULL, NULL IS NULL;

-- Ловушка 2. AND / OR — выполнить и объяснить результат
SELECT count(*)
FROM vacancies
WHERE
    area_id = 1
    OR area_id = 2
    AND experience = 'Нет опыта';

SELECT count(*)
FROM vacancies
WHERE (
        area_id = 1
        OR area_id = 2
    )
    AND experience = 'Нет опыта';

-- Вывод:
-- Первый запрос вернул 0, а не ошибку. Сравнение с NULL через = дает не true или false, а NULL,
-- и WHERE просто выкидывает такие строки. Это хуже ошибки, потому что запрос работает, но ответ неправильный и в него можно поверить.
-- Содержательно NULL в closed_at значит, что вакансия еще открыта: через IS NULL их нашлось 33.
-- Во второй паре AND выполняется раньше OR, поэтому первое условие база читает как
-- area_id = 1 OR (area_id = 2 AND experience = 'Нет опыта'), и для Москвы условие про опыт теряется.
-- Первый запрос вернул 31, второй 20; разница 11 - это московские вакансии с опытом.
-- На вопрос "Москва или Питер, но обязательно без опыта" отвечает второй запрос, со скобками.

-- ============================================================
-- БЛОК В. Агрегации и метрики
-- ============================================================

-- ЗАДАНИЕ В1
-- Запрос 1: счётчики (строки, зарплата указана, направления, работодатели)
SELECT
    COUNT(*) AS "Строки",
    COUNT(salary_from) AS "С указанной нижней границей",
    COUNT(DISTINCT professional_role) AS "Роли (направления)",
    COUNT(DISTINCT employer_id) AS "Работодатели"
FROM vacancies;

SELECT
    COUNT(
        CASE
            WHEN salary_from IS NOT NULL AND salary_to IS NOT NULL THEN 1
        END
    ) AS "Диапазон зарплаты указан",
    COUNT(
        CASE
            WHEN salary_from IS NOT NULL AND salary_to IS NULL THEN 1
        END
    ) AS "Только минимальная зарплата",
    COUNT(
        CASE
            WHEN salary_from IS NULL AND salary_to IS NOT NULL THEN 1
        END
    ) AS "Только максимальная зарплата",
    COUNT(
        CASE
            WHEN salary_from IS NULL AND salary_to IS NULL THEN 1
        END
    ) AS "Зарплата вообще не указана"
FROM vacancies;

SELECT
    professional_role,
    COUNT(professional_role) AS "Количество вакансий"
FROM vacancies
GROUP BY
    professional_role
LIMIT 100;

SELECT e.employer_name, COUNT(e.employer_id) AS "Количество вакансий", e.employer_id
FROM vacancies v
    LEFT JOIN employers e ON e.employer_id = v.employer_id
GROUP BY
    e.employer_id
LIMIT 100;

-- Запрос 2: доля активных вакансий (без JOIN)
SELECT
    COUNT(*) FILTER (WHERE closed_at IS NULL) AS "Открытые",
    COUNT(*) FILTER (WHERE closed_at IS NOT NULL) AS "Закрытые",
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE closed_at IS NULL)
        / NULLIF(COUNT(*), 0),
        1) AS "Процент открытых"
FROM vacancies;

-- Вывод:
-- Мы сделали запросы, которые позволяют нам узнать о том, какие данные есть в таблицах и сколько их.
-- count(*) дал 52, а count(salary_from) 44, потому что у 8 вакансий зарплата не указана, то есть
-- count(колонка) не считает NULL, а count(*) считает все. Разных направлений 5, хотя строк с направлением
-- тоже 52, потому что count(DISTINCT) убирает повторы.

-- Cейчас открыто 33 вакансии из 52, это 63,5%.

-- ЗАДАНИЕ В2
-- Запрос 1: направления, вакансии, работодатели, средняя зарплата
SELECT
    professional_role,
    COUNT(*) AS "Количество вакансий",
    ROUND(AVG(salary_from)) AS "Средняя нижняя граница",
    COUNT(DISTINCT employer_id) AS "Количество работодателей"
FROM vacancies
GROUP BY
    professional_role
ORDER BY "Количество вакансий" DESC;

SELECT
    e.employer_name,
    COUNT(*) AS "Количество вакансий",
    COUNT(DISTINCT professional_role) AS "Количество направлений",
    e.employer_id
FROM vacancies v
    LEFT JOIN employers e ON e.employer_id = v.employer_id
GROUP BY
    e.employer_id
LIMIT 100;

-- Запрос 2: то же, только направления с ≥ 5 открытыми вакансиями (WHERE + HAVING)
SELECT
    professional_role,
    COUNT(*) AS "Количество вакансий",
    ROUND(AVG(salary_from)) AS "Средняя нижняя граница",
    COUNT(DISTINCT employer_id) AS "Количество работодателей"
FROM vacancies
WHERE
    closed_at IS NULL
GROUP BY
    professional_role
HAVING
    COUNT(*) >= 5
ORDER BY "Количество вакансий" DESC;

-- Вывод:
-- Мы изучили вакансии по направлениям. Больше половины рынка дают два направления: "Аналитик данных"
-- (16) и "Разработчик" (15), вместе 31 из 52, то есть они занимают больше половины рынка. 
-- Если оставить только открытые, то направлений остается 4, а "Продуктовый аналитик" выпадает, у него всего 4 открытые вакансии из 7.
-- Но по одной этой таблице можно решить, что аналитик самый перспективный, а тут нет ни откликов,
-- ни конверсии, поэтому про реальную востребованность сказать нельзя.
-- Открытые вакансии мы пишем в WHERE, потому что это условие на строки до группировки, а >=5 -
-- на результат группировки, поэтому HAVING. Если написать WHERE count(*) >= 5, будет ошибка, потому что
-- агрегаты в WHERE писать нельзя.
-- avg(salary_from) отвечает на вопрос про среднюю заявленную нижнюю границу зарплаты, а на вопрос, сколько
-- реально платят. Верхняя граница и факт найма не учтены.

-- ============================================================
-- БЛОК Г. Соединение таблиц
-- ============================================================

-- ЗАДАНИЕ Г1
-- Запрос: топ-5 по salary_from с названием компании и городом (псевдонимы таблиц)
SELECT v.professional_role, v.vacancy_name, v.salary_from, e.employer_name, a.area_name, v.vacancy_id
FROM
    vacancies v
    LEFT JOIN employers e ON e.employer_id = v.employer_id
    LEFT JOIN areas a ON a.area_id = v.area_id
WHERE
    salary_from IS NOT NULL
ORDER BY salary_from DESC
LIMIT 5;
-- Вывод:
-- Мы получили топ 5 вакансий по salary_from. Отсеяли, где NULL.
-- Если убрать псевдонимы и написать просто area_id, будет ошибка, потому что такая колонка есть и в
-- vacancies, и в areas, и база не поймет, из какой таблицы ее брать.

-- ЗАДАНИЕ Г2
-- Запрос 1: все работодатели, число вакансий и откликов (LEFT JOIN)
SELECT
    e.employer_id,
    e.employer_name,
    COUNT(DISTINCT v.vacancy_id) AS "Вакансии",
    COUNT(r.response_id) AS "Отклики"
FROM
    employers e
    LEFT JOIN vacancies v ON v.employer_id = e.employer_id
    LEFT JOIN responses r ON r.vacancy_id = v.vacancy_id
GROUP BY
    e.employer_id, e.employer_name
ORDER BY "Отклики" DESC;

-- Запрос 2: тот же запрос с INNER JOIN
SELECT
    e.employer_id,
    e.employer_name,
    COUNT(DISTINCT v.vacancy_id) AS "Вакансии",
    COUNT(r.response_id) AS "Отклики"
FROM
    employers e
    INNER JOIN vacancies v ON v.employer_id = e.employer_id
    INNER JOIN responses r ON r.vacancy_id = v.vacancy_id
GROUP BY
    e.employer_id, e.employer_name
ORDER BY "Отклики" DESC;

-- Проверяем ГринЭнерго
SELECT 
    v.vacancy_id,
    v.vacancy_name,
    v.published_at,
    v.closed_at,
    COUNT(r.response_id) AS "Отклики"
FROM
    employers e
    LEFT JOIN vacancies v ON v.employer_id = e.employer_id
    LEFT JOIN responses r ON r.vacancy_id = v.vacancy_id
WHERE e.employer_id = 111 -- ГринЭнерго
GROUP BY v.vacancy_id;

-- Вывод:
-- В первом запросе мы получили всех работодателей, даже тех, у кого нет вакансий или откликов, потому
-- что слева стоит employers и LEFT JOIN ничего не выбрасывает. Во втором случае остаются только те,
-- у кого есть хотя бы одна вакансия с хотя бы одним откликом.
-- Вакансии мы считаем через count(DISTINCT v.vacancy_id), потому что после JOIN с responses вакансия
-- повторяется столько раз, сколько у нее откликов, и count(*) посчитал бы эти пары.
-- В первом запросе вышло 12 работодателей, а во втором 11: пропадает "ГринЭнерго", у которой одна вакансия
-- и ноль откликов, то есть именно то, что искал HR, поэтому потеря содержательная. Эта вакансия была открыта
-- с 2026-04-06 до 2026-05-4, но ни одного отклика она не получила.
-- LEFT JOIN, когда нужны все строки слева, даже без совпадений, а INNER, когда нужны только совпадения.

-- ============================================================
-- БЛОК Д. Функции и финальный кейс
-- ============================================================

-- ЗАДАНИЕ Д1
-- Запрос: помесячная динамика откликов и конверсия
-- (месяц как дата, условный агрегат, nullif в знаменателе)

SELECT
    date_trunc('month', created_at)::date AS "month",
    MAX(created_at) AS "Конец месяца", -- показывает 15 августа
    COUNT(*) AS "Отклики",
    COUNT(*) FILTER (WHERE status = 'invited') AS "Приглашения",
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE status = 'invited')
        / NULLIF(COUNT(*), 0),
        1) AS "Конверсия, %"
FROM responses
GROUP BY
    date_trunc('month', created_at)::date
ORDER BY "month";

-- Вывод:
-- Максимальная конверсия в июне 2026 - 19,5%, и июню как раз
-- можно доверять, потому что 118 откликов это второй по объему месяц после июля, а не 20 штук, где процент
-- скачет от одного приглашения.
-- А август в выводы лучше не брать, потому что данные обрываются 15 числа,
-- там всего 41 отклик против 118-142 в июне и июле, то есть месяц неполный и сравнивать их будет некорректно.

-- ЗАДАНИЕ Д2
-- Запрос: таблица по направлениям (вакансии, отклики, приглашения,
-- откликов на вакансию, конверсия)
SELECT
    v.professional_role,
    COUNT(DISTINCT v.vacancy_id) AS vacancies,
    COUNT(r.response_id) AS responses,
    COUNT(r.response_id) FILTER (
        WHERE
            r.status = 'invited'
    ) AS "Приглашения",
    ROUND(
        COUNT(r.response_id)::numeric 
        / NULLIF(COUNT(DISTINCT v.vacancy_id), 0),
        2) AS responses_per_vacancy,
    ROUND(
        100.0 * COUNT(r.response_id) FILTER (WHERE r.status = 'invited')
        / NULLIF(COUNT(r.response_id), 0),
        1) AS "Конверсия, %"
FROM vacancies v
    LEFT JOIN responses r ON v.vacancy_id = r.vacancy_id
GROUP BY
    v.professional_role
ORDER BY vacancies DESC;

-- Письменные ответы:
-- 1. Совпадает ли направление с наибольшим числом вакансий с направлением
--    с наибольшей конверсией?
-- Нет, не совпадают: больше всего вакансий у "Аналитика данных", а наибольшая конверсия у "Тестировщика"

-- 2. Какое направление выбрать и почему (опираясь на два столбца):
-- Тестировщик выглядит как наиболее удачный вариант, потому что у него наибольшая конверсия и запросов
--  на вакансию не так много - 5,57 против 19,56 у "Аналитика данных", то есть низкая конкуренция

-- 3. Оговорка к выводу:
-- У нас очень небольшая выборка данных, поэтому выбросы сильно влияют на наши показатели - у "Тестировщика"
-- всего 7 вакансий и 39 откликов. Вакансий на тестировзиков меньше, чем некоторых остальных. Нам скорее
-- нужно смотреть на текущие открытые вакансии и отклики на них и на работодателя.

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
-- 1. Проверка на NULL с помощью оператора сравнения "=": условие v.closed_at = NULL никогда не истинно,
--  поэтому запрос возвращает ноль строк, а надо через IS NULL
-- 2. Используется не JOIN без LEFT (равносильно INNER), что выбрасывает вакансии без откликов
-- 3. Неправильный подсчет количества откликов на вакансию: count(*) после JOIN считает пары "вакансия-отклик",
--  а не вакансии, плюс отсутствие NULLIF при делении
-- 4. Неправильный расчет зарплаты: если мы хотим получить среднюю зарплату по этим направлениям, то нам нужно
--  брать среднее (или по распределению, если у нас есть данные) между salary_from и salary_to и брать среднее
--  от них. А считать сумму минимальных зарплат по направлению как будто не имеет смысла без доп группировок
--

-- Исправленный запрос:
WITH vacancy_responses AS (
    SELECT vacancy_id, COUNT(*) AS responses
    FROM responses
    GROUP BY vacancy_id
)
SELECT
    v.professional_role,
    COUNT(*) AS vacancies,
    ROUND(
        AVG(
            (COALESCE(v.salary_from, v.salary_to)
             + COALESCE(v.salary_to, v.salary_from))
            / 2
            )
        ) AS "Cередина зарплатных вилок",
    ROUND(
        SUM(COALESCE(vr.responses, 0))::numeric
        / NULLIF(COUNT(*), 0),
        2) AS responses_per_vacancy
FROM vacancies v
    LEFT JOIN vacancy_responses vr ON vr.vacancy_id = v.vacancy_id
WHERE v.closed_at IS NULL
GROUP BY v.professional_role
ORDER BY vacancies DESC;

-- Какие два правила из лекции защитили бы от этих ошибок при написании запроса:
-- 1. Нужно продумывать то, что мы хотим получить, потом, как мы хотим получить
-- 2. Нужно следить за гранулярностью
-- + думать
