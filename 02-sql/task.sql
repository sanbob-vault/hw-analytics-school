
-- ====================================
-- 1. Аудит качества данных
-- ====================================

-- EDA
-- Базово изучаем таблицы
SELECT * FROM responses LIMIT 10;
SELECT * FROM calls LIMIT 10;
SELECT * FROM messages LIMIT 10;

-- (Я использую клиент, который автоматически
-- ставит LIMIT, если в запросе он отсутствует)

-- В messages есть FK на response_id, и он обязателен, у всех сообщений есть отклик.
-- В calls есть FK на response_id, но он не обязателен - это важная деталь.
SELECT
    COUNT(*) AS "Сообщений",
    COUNT(DISTINCT response_id) AS "Откликов с сообщениями"
FROM messages;
-- 2862 сообщения распределены по 477 откликам.

SELECT
    COUNT(*) AS "Звонков",
    COUNT(DISTINCT response_id) AS "Откликов со звонками",
    COUNT(*) FILTER (WHERE response_id IS NOT NULL) AS "Звонков с откликами"
FROM calls;
-- 251 звонок, из которых только 243 относятся к откликам. При чем 243 звонка распределены по 220 откликам.
-- Важно: 8 звонков без откликов

-- Смотрим средние показатели
WITH responses_with_events_count AS (
    SELECT
        r.response_id,
        COUNT(DISTINCT m.message_id) AS message_count,
        COUNT(DISTINCT c.call_id) AS call_count
    FROM responses r
    LEFT JOIN messages m ON m.response_id = r.response_id
    LEFT JOIN calls c ON c.response_id = r.response_id
    GROUP BY r.response_id
)
SELECT
    COUNT(response_id) AS "Откликов",
    AVG(message_count) AS "Сообщений на отклик",
    AVG(call_count) AS "Звонков на отклик"
FROM responses_with_events_count;
-- Количество сообщений и звонков в среднем на один отклик

-- Анализируем распределение сообщений
WITH responses_with_events_count AS (
    SELECT
        r.response_id,
        COUNT(DISTINCT m.message_id) AS message_count
    FROM responses r
    LEFT JOIN messages m ON m.response_id = r.response_id
    GROUP BY r.response_id
)
SELECT
    message_count,
    COUNT(message_count) AS responses_count
FROM responses_with_events_count
GROUP BY message_count
ORDER BY message_count DESC;
-- Видим, что в таблице есть только отклики, у которых либо 0, либо 6 сообщений: 477 откликов по 6 сообщений, 151 отклик по 0.

-- Проверим
SELECT 
    477 * 6,
    COUNT(DISTINCT message_id)
FROM messages;
-- 2862 - мы получаем количество всех наших сообщений

-- Анализируем распределение звонков
WITH responses_with_events_count AS (
    SELECT
        r.response_id,
        COUNT(DISTINCT c.call_id) AS call_count
    FROM responses r
    LEFT JOIN calls c ON c.response_id = r.response_id
    GROUP BY r.response_id
)
SELECT
    call_count,
    COUNT(call_count) AS responses_count
FROM responses_with_events_count
GROUP BY call_count
ORDER BY call_count DESC;
-- Получаем: 23 отклика по 2 звонка, 197 откликов по 1 звонку, 408 откликов без звонков.

-- Проверяем
SELECT 
    23 * 2 + 197 * 1,
    COUNT(DISTINCT call_id)
FROM calls
WHERE response_id IS NOT NULL;
-- 243 = 243

-- Проверяем качество данных и ищем аномалии в них
WITH checks AS (
    SELECT 
        'Звонок до отклика' AS issue_type, -- пишем названия для колонок только в первой таблице
        c.call_id::text AS problem_id
    FROM calls c
    JOIN responses r ON c.response_id = r.response_id
    WHERE c.call_at < r.created_at
    
    UNION ALL
    
    SELECT 
        'Рассинхрон id у звонка',
        c.call_id::text
    FROM calls c 
    JOIN responses r ON c.response_id = r.response_id
    JOIN vacancies v ON r.vacancy_id = v.vacancy_id
    WHERE c.vacancy_id != r.vacancy_id OR c.employer_id != v.employer_id

    UNION ALL

    SELECT 
        'Сообщение до отклика',
        m.message_id::text
    FROM messages m JOIN responses r ON m.response_id = r.response_id
    WHERE m.sent_at < r.created_at
    
    UNION ALL
    
    SELECT 
        'Рассинхрон id у сообщения',
        m.message_id::text
    FROM messages m 
    JOIN responses r ON m.response_id = r.response_id
    JOIN vacancies v ON r.vacancy_id = v.vacancy_id
    WHERE m.vacancy_id != r.vacancy_id OR m.employer_id != v.employer_id
)
SELECT 
    issue_type,
    COUNT(*),
    ARRAY_AGG(problem_id) AS problem_ids
FROM checks
GROUP BY issue_type;

-- Мы не нашли
-- Звонков или сообщений, которые бы произошли до отклика, что ломало бы смысл связи
-- Звонков или сообщений, у которых id вакансии или работодателя отличались бы от отклика, что тоже ломало бы смысл связи

SELECT call_id
FROM calls
WHERE call_duration <= 0;
-- Звонков нулевой длительности нет
-- Это правило есть на уровне бд

SELECT message_id
FROM messages
WHERE message_text IS NULL OR message_text = '';
-- Сообщений без текста нет


-- Посмотрим на звонки без откликов.
SELECT *
FROM calls
WHERE response_id IS NULL
LIMIT 10;

-- При чем, у таких звонков все равно есть айди вакансий и работодателей, потому что это обязательные поля.
-- Изучим
WITH calls_wo_response_id AS (
    SELECT *
    FROM calls
    WHERE response_id IS NULL
    LIMIT 10
)
SELECT
    c.call_id,
    c.status,
    c.call_duration,
    v.vacancy_id,
    v.professional_role,
    v.employer_id AS "employer_id у вакансии",
    c.employer_id AS "employer_id у звонка",
    v.employer_id = c.employer_id AS "Все совпадает?"
FROM calls_wo_response_id c
LEFT JOIN vacancies v ON v.vacancy_id = c.vacancy_id
LEFT JOIN employers e ON e.employer_id = c.employer_id;

-- Видим, что все поля у таких звонков совпадают правильно, то есть они выглядят так,
-- как будто просто потеряли response_id

WITH calls_wo_response_id AS (
    SELECT *
    FROM calls
    WHERE response_id IS NULL
    LIMIT 10
),
calls_joined AS (
    SELECT
        c.call_id,
        c.status,
        c.call_duration,
        v.vacancy_id
    FROM calls_wo_response_id c
    LEFT JOIN vacancies v ON v.vacancy_id = c.vacancy_id
    LEFT JOIN employers e ON e.employer_id = c.employer_id
)
SELECT
    c.call_id,
    COUNT(DISTINCT c.vacancy_id) AS "v_count", -- мы имеем только по одной вакансии на звонок
    MAX(c.vacancy_id) AS "vacancy_id", -- поэтому можем сделать так
    COUNT(r.response_id) AS "responses_count"
FROM calls_joined c
LEFT JOIN responses r ON r.vacancy_id = c.vacancy_id
GROUP BY c.call_id;

-- Все выглядит действительно так: вакансии, к которым прикреплены эти звонки имеют отклики
-- но, я думаю, чтобы использовать такие данные с уверенностью в том, что они правильные -
-- нужно спрашивать у разработчиков, что происходит с такими звонками, поэтому мы будем игнорировать их

-- Изучим звонки
-- Сначала посмотрим на базовое распределение и перцентили
WITH valid_calls AS (
    SELECT call_duration
    FROM calls
    WHERE status = 'successful'
)
SELECT
    ROUND(AVG(call_duration), 2) AS "Средняя длительность",
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY call_duration) AS "Медиана",
    PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY call_duration) AS "99 перцентиль"
FROM valid_calls;
-- Получаем метрики

-- Теперь посчитаем количество звонков за этой границей и среднее без них
WITH valid_calls AS (
    SELECT call_duration
    FROM calls
    WHERE status = 'successful'
),
p99_calc AS (
    SELECT 
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY call_duration) AS p99_val
    FROM valid_calls
)
SELECT 
    COUNT(v.call_duration) FILTER (WHERE v.call_duration > p.p99_val) AS "Звонков выше 99",
    ROUND(AVG(v.call_duration) FILTER (WHERE v.call_duration <= p.p99_val), 2) AS "Средняя длительность без 99"
FROM valid_calls v
CROSS JOIN p99_calc p;

-- Звонки выше 99 перцентиля
WITH p99_calc AS (
    SELECT 
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY call_duration) AS p99_val
    FROM (SELECT * FROM calls WHERE status = 'successful')
)
SELECT *
FROM calls
CROSS JOIN p99_calc p
WHERE status = 'successful' AND call_duration > p.p99_val
LIMIT 10;

-- Значения длительности звонков выше 99 перцентиля я бы считал допустимыми значениями, потому что они не выбиваются от остальных
-- и они выглядят правдоподобно, так как их длина не сильно больше, чем у остальных. Они не сильно влияют на среднюю длительность.
-- (467.28 vs 463.49 - средняя длительность)

-- Данные достаточно чистые: Событий до отклика и рассинхрона id не найдено. Ошибок нулевой или отрицательной длительности также нет.
-- Единственная аномалия логики - 8 звонков без response_id. Влияет на факт коммуникации: их невозможно достоверно привязать к конкретным откликам, поэтому в дальнейших расчетах мы их исключаем.
-- Метрики длительности звонков: среднее - 467.28, медиана - 438, 99-й перцентиль - 890.4.


-- ====================================
-- 2. Единый слой коммуникаций
-- ====================================

-- Собираем события, которые нам нужны вместе: сообщения и звонки
-- Исключаем аномалии и берем только те, где отправитель - работодатель и прошло не более 7 дней
WITH messages_7d AS (
    SELECT 
        m.response_id,
        m.employer_id,
        m.message_id AS event_id,
        m.sent_at AS event_at,
        'message' AS event_type
    FROM messages m
    JOIN responses r ON m.response_id = r.response_id
    WHERE m.sender_role = 'employer' 
      AND m.sent_at >= r.created_at 
      AND m.sent_at <= r.created_at + INTERVAL '7 days'
),
calls_7d AS (
    SELECT 
        c.response_id,
        c.employer_id,
        c.call_id AS event_id,
        c.call_at AS event_at,
        'call' AS event_type
    FROM calls c
    JOIN responses r ON c.response_id = r.response_id
    WHERE c.caller_role = 'employer'
      AND c.response_id IS NOT NULL -- без аномалий
      AND c.call_at >= r.created_at 
      AND c.call_at <= r.created_at + INTERVAL '7 days'
)
SELECT * FROM messages_7d
UNION ALL
SELECT * FROM calls_7d
LIMIT 10;

-- Агрегируем наши события и считаем
WITH messages_7d AS (
    SELECT 
        m.response_id,
        m.employer_id,
        m.message_id AS event_id,
        m.sent_at AS event_at,
        'message' AS event_type
    FROM messages m
    JOIN responses r ON m.response_id = r.response_id
    WHERE m.sender_role = 'employer' 
      AND m.sent_at >= r.created_at 
      AND m.sent_at <= r.created_at + INTERVAL '7 days'
),
calls_7d AS (
    SELECT 
        c.response_id,
        c.employer_id,
        c.call_id AS event_id,
        c.call_at AS event_at,
        'call' AS event_type
    FROM calls c
    JOIN responses r ON c.response_id = r.response_id
    WHERE c.caller_role = 'employer'
      AND c.response_id IS NOT NULL -- без аномалий
      AND c.call_at >= r.created_at 
      AND c.call_at <= r.created_at + INTERVAL '7 days'
),
events AS (
    SELECT * FROM messages_7d
    UNION ALL
    SELECT * FROM calls_7d
)
SELECT
    COUNT(*) AS "Общее количество событий",
    COUNT(DISTINCT response_id) AS "Откликов с коммуникацией",
    COUNT(*) FILTER (WHERE event_type = 'call') AS "Количество звонков",
    COUNT(*) FILTER (WHERE event_type = 'message') AS "Количество сообщений"
FROM events;

-- Общее количество событий: 1096
-- Количество различных откликов с коммуникацией: 382
-- Количество звонков: 108
-- Количество сообщений: 988

-- =======================================================
-- 3. Таймлайн коммуникаций и витрина отклика
-- =======================================================

-- Я решаю создать временную таблицу, чтобы избавиться от большого количества дублирования кода и увеличить читаемость
-- По идее, если аналитики часто используют одни и те же данные, то их, по хорошему, стоит вынести во view или похожие инструменты,
-- которые помогут оптимизировать запросы к бд, повысить читаемость кода и ускорить и повысить удобство работы аналитиков 
CREATE TEMPORARY TABLE events AS (
    WITH messages_7d AS (
        SELECT 
            m.response_id,
            m.employer_id,
            m.message_id AS event_id,
            m.sent_at AS event_at,
            'message' AS event_type
        FROM messages m
        JOIN responses r ON m.response_id = r.response_id
        WHERE m.sender_role = 'employer' 
        AND m.sent_at >= r.created_at 
        AND m.sent_at <= r.created_at + INTERVAL '7 days'
    ),
    calls_7d AS (
        SELECT 
            c.response_id,
            c.employer_id,
            c.call_id AS event_id,
            c.call_at AS event_at,
            'call' AS event_type
        FROM calls c
        JOIN responses r ON c.response_id = r.response_id
        WHERE c.caller_role = 'employer'
        AND c.response_id IS NOT NULL -- без аномалий
        AND c.call_at >= r.created_at 
        AND c.call_at <= r.created_at + INTERVAL '7 days'
    )
    SELECT * FROM messages_7d
    UNION ALL
    SELECT * FROM calls_7d
);

-- Таймлайн
-- Считаем значения для таймлайна
-- Его тоже используем несколько раз и он достаточно большой, поэтому буду использовать временную таблицу
CREATE TEMPORARY TABLE timeline AS (
    SELECT 
        response_id,
        employer_id,
        event_id,
        event_at,
        event_type,
        -- Порядковый номер события
        ROW_NUMBER() OVER (
            PARTITION BY response_id 
            ORDER BY event_at, event_type, event_id
        ) AS row_num,
        -- Время предыдущего события
        LAG(event_at) OVER (
            PARTITION BY response_id 
            ORDER BY event_at, event_type, event_id
        ) AS prev_event_at,
        -- Тип следующего события
        LEAD(event_type) OVER (
            PARTITION BY response_id 
            ORDER BY event_at, event_type, event_id
        ) AS next_event_type,
        -- Накопительное количество коммуникаций
        COUNT(*) OVER (
            PARTITION BY response_id 
            ORDER BY event_at, event_type, event_id 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS current_event_num,
        -- Тип первой коммуникации
        FIRST_VALUE(event_type) OVER (
            PARTITION BY response_id 
            ORDER BY event_at, event_type, event_id
        ) AS first_event_type,
        -- Тип последней коммуникации (обязательно расширяем рамку)
        LAST_VALUE(event_type) OVER (
            PARTITION BY response_id 
            ORDER BY event_at, event_type, event_id 
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS last_event_type
    FROM events -- используем временную таблицу (в случае чего можно просто вернуть CTE сюда)
);

SELECT * FROM timeline LIMIT 20; -- используем временную таблицу (в случае чего можно просто вернуть CTE сюда)

-- Витрина уровня отклика
-- Агрегируем таймлайн до уровня отклика и собираем полезную информацию вместе

WITH timeline_agg AS (
    SELECT 
        response_id,
        COUNT(*) AS total_events,
        COUNT(*) FILTER (WHERE event_type = 'call') AS call_count,
        COUNT(*) FILTER (WHERE event_type = 'message') AS message_count,
        MIN(event_at) AS first_event_at,
        MAX(event_type) FILTER (WHERE row_num = 1) AS first_event_type,
        MAX(event_type) FILTER (WHERE row_num = 2) AS second_event_type,
        MAX(last_event_type) AS last_event_type,
        MAX(EXTRACT(EPOCH FROM (event_at - prev_event_at)) / 3600.0) AS max_interval_hours -- интервал в часах между событиями
    FROM timeline
    GROUP BY response_id
),
showcase AS (
    SELECT 
        r.response_id,
        v.employer_id,
        v.professional_role AS "Профессия",
        r.status AS "Статус отклика",
        COALESCE(ta.total_events, 0) AS "Коммуникаций",
        COALESCE(ta.call_count, 0) AS "Звонков",
        COALESCE(ta.message_count, 0) AS "Сообщений",
        ta.first_event_at AS "Время первой коммуникации",
        ta.first_event_type AS "Тип первой коммуникации",
        ta.second_event_type AS "Тип второй коммуникации",
        ta.last_event_type AS "Тип последней коммуникации",
        EXTRACT(EPOCH FROM (ta.first_event_at - r.created_at)) / 3600.0 AS "От отклика до первой комм",
        ta.max_interval_hours AS "Макс интервал между комм"
    FROM responses r
    JOIN vacancies v ON r.vacancy_id = v.vacancy_id
    LEFT JOIN timeline_agg ta ON r.response_id = ta.response_id -- Оставляем отклики без событий
)
SELECT * 
FROM showcase
LIMIT 10;

-- Получаем 5 контрольных значений
WITH timeline_agg AS (
    SELECT 
        response_id,
        COUNT(*) AS total_events,
        COUNT(*) FILTER (WHERE event_type = 'call') AS call_count,
        COUNT(*) FILTER (WHERE event_type = 'message') AS message_count,
        MIN(event_at) AS first_event_at,
        MAX(event_type) FILTER (WHERE row_num = 1) AS first_event_type,
        MAX(event_type) FILTER (WHERE row_num = 2) AS second_event_type,
        MAX(last_event_type) AS last_event_type,
        MAX(EXTRACT(EPOCH FROM (event_at - prev_event_at)) / 3600.0) AS max_interval_hours -- интервал в часах между событиями
    FROM timeline
    GROUP BY response_id
),
showcase AS (
    SELECT 
        r.response_id,
        v.employer_id,
        v.professional_role AS "Профессия",
        r.status AS "Статус отклика",
        COALESCE(ta.total_events, 0) AS "Коммуникаций",
        COALESCE(ta.call_count, 0) AS "Звонков",
        COALESCE(ta.message_count, 0) AS "Сообщений",
        ta.first_event_at AS "Время первой коммуникации",
        ta.first_event_type AS "Тип первой коммуникации",
        ta.second_event_type AS "Тип второй коммуникации",
        ta.last_event_type AS "Тип последней коммуникации",
        EXTRACT(EPOCH FROM (ta.first_event_at - r.created_at)) / 3600.0 AS "От отклика до первой комм",
        ta.max_interval_hours AS "Макс интервал между комм"
    FROM responses r
    JOIN vacancies v ON r.vacancy_id = v.vacancy_id
    LEFT JOIN timeline_agg ta ON r.response_id = ta.response_id -- Оставляем отклики без событий
)
SELECT 
    COUNT(*) AS "Количество строк",
    COUNT(*) FILTER (WHERE "Тип первой коммуникации" IS NOT NULL) AS "Откликов с коммуникацией",
    COUNT(*) FILTER (WHERE "Тип первой коммуникации" IS NULL) AS "Откликов без коммуникации",
    COUNT(*) FILTER (WHERE "Тип первой коммуникации" = 'message') AS "Первая коммуникация - сообщение",
    COUNT(*) FILTER (WHERE "Тип первой коммуникации" = 'call') AS "Первая коммуникация - звонок"
FROM showcase;

SELECT 
    (314 + 68) = 382 AS "Проверка откликов с комм",
    (382 + 246) = 628 AS "Проверка всего откликов";

-- Количество строк: 628
-- Количество откликов с коммуникацией: 382
-- Количество откликов без коммуникации: 246
-- Количество откликов, где первой коммуникацией было сообщение: 314
-- Количество откликов, где первой коммуникацией был звонок: 68


-- =======================================================
-- 4. Рейтинг работодателей внутри направления
-- =======================================================

-- Витрина тоже пригождается много где, поэтому я решил и ее создать)
-- Я не люблю дублирование кода, потому что это причина большого количества ошибок - теряется один единственный источник правды и при обновлении нужно обновлять везде
-- Здесь назову колонки не для вывода, а для удобного использования в дальнейших запросах
CREATE TEMPORARY TABLE showcase AS (
    WITH timeline_agg AS (
        SELECT 
            response_id,
            COUNT(*) AS total_events,
            COUNT(*) FILTER (WHERE event_type = 'call') AS call_count,
            COUNT(*) FILTER (WHERE event_type = 'message') AS message_count,
            MIN(event_at) AS first_event_at,
            MAX(event_type) FILTER (WHERE row_num = 1) AS first_event_type,
            MAX(event_type) FILTER (WHERE row_num = 2) AS second_event_type,
            MAX(last_event_type) AS last_event_type,
            MAX(EXTRACT(EPOCH FROM (event_at - prev_event_at)) / 3600.0) AS max_interval_hours -- интервал в часах между событиями
        FROM timeline
        GROUP BY response_id
    )
    SELECT 
        r.response_id,
        v.employer_id,
        v.professional_role,
        r.status,
        COALESCE(ta.total_events, 0) AS total_events,
        COALESCE(ta.call_count, 0) AS call_count,
        COALESCE(ta.message_count, 0) AS message_count,
        ta.first_event_at,
        ta.first_event_type,
        ta.second_event_type,
        ta.last_event_type,
        EXTRACT(EPOCH FROM (ta.first_event_at - r.created_at)) / 3600.0 AS hours_to_first_comm,
        ta.max_interval_hours
    FROM responses r
    JOIN vacancies v ON r.vacancy_id = v.vacancy_id
    LEFT JOIN timeline_agg ta ON r.response_id = ta.response_id -- Оставляем отклики без событий
);

-- Проверяем, что витрина собралась корректно
SELECT * FROM showcase LIMIT 10;

WITH employer_stats AS (
    SELECT 
        professional_role,
        employer_id,
        COUNT(response_id) AS total_responses,
        COUNT(response_id) FILTER (WHERE first_event_type IS NOT NULL) AS comm_responses, -- Количество откликов с коммуникацией
        ROUND(
            COUNT(response_id) FILTER (WHERE first_event_type IS NOT NULL) * 100.0 / COUNT(response_id), 
            2
        ) AS comm_share, -- Доля откликов с коммуникацией в процентах
        -- Медиана и 90-й перцентиль времени
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY hours_to_first_comm) AS median_time, 
        PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY hours_to_first_comm) AS p90_time,
        ROUND(
            COUNT(response_id) FILTER (WHERE status = 'invited') * 100.0 / COUNT(response_id), 
            2
        ) AS invite_conversion -- Конверсия в приглашение в процентах
    FROM showcase
    GROUP BY professional_role, employer_id
    HAVING COUNT(response_id) >= 8 -- Берем только работодателей с >= 8 откликов
),
ranked_employers AS (
    SELECT 
        professional_role,
        employer_id,
        total_responses,
        comm_share,
        median_time,
        p90_time,
        invite_conversion,
        DENSE_RANK() OVER ( -- без пропуска мест
            PARTITION BY professional_role 
            ORDER BY 
                comm_share DESC, -- больше доля откликов
                median_time ASC -- меньше медиана времени
        ) AS place
    FROM employer_stats
)
SELECT 
    professional_role,
    place,
    employer_id,
    total_responses,
    comm_share,
    median_time,
    p90_time,
    invite_conversion
FROM ranked_employers
WHERE place <= 2
ORDER BY professional_role, place, employer_id;

-- professional_role    | место | employer_id
-- ---------------------+-------+------------
-- Аналитик данных      | 1     | 109
-- Аналитик данных      | 2     | 103
-- Дата-инженер         | 1     | 106
-- Дата-инженер         | 2     | 101
-- Продуктовый аналитик | 1     | 103
-- Продуктовый аналитик | 2     | 102
-- Разработчик          | 1     | 112
-- Разработчик          | 2     | 104
-- Тестировщик          | 1     | 107
-- Тестировщик          | 2     | 108


-- =======================================================
-- 5. Скорость ответа работодателя в переписке
-- =======================================================

WITH valid_messages AS (
    SELECT 
        m.response_id,
        m.employer_id,
        m.message_id,
        m.sent_at,
        m.sender_role
    FROM messages m
    JOIN responses r ON m.response_id = r.response_id
    JOIN vacancies v ON r.vacancy_id = v.vacancy_id
    WHERE m.sent_at <= r.created_at + INTERVAL '7 days'
),
messages_with_lag AS (
    SELECT 
        response_id,
        employer_id,
        sent_at,
        sender_role,
        LAG(sender_role) OVER (
            PARTITION BY response_id 
            ORDER BY sent_at, message_id
        ) AS prev_sender_role,
        LAG(sent_at) OVER (
            PARTITION BY response_id 
            ORDER BY sent_at, message_id
        ) AS prev_sent_at
    FROM valid_messages
),
replies AS (
    SELECT 
        employer_id,
        SUM(1) OVER() AS all_replies_count,
        (EXTRACT(EPOCH FROM (sent_at - prev_sent_at)) / 3600.0) AS reply_hours
    FROM messages_with_lag
    WHERE sender_role = 'employer' AND prev_sender_role = 'applicant'
),
employer_speed AS (
    SELECT 
        employer_id,
        COUNT(*) AS replies_count,
        ROUND(AVG(reply_hours), 3) AS avg_reply_time,
        -- PERCENTILE_CONT интерполирует значения, если процентиль между 2 строками, поэтому округляю здесь
        ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY reply_hours)::NUMERIC, 3) AS median_reply_time,
        ROUND(PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY reply_hours)::NUMERIC, 3) AS p90_reply_time,
        MIN(all_replies_count) AS all_replies_count -- имеем только одно значение
    FROM replies
    GROUP BY employer_id
)
SELECT *
FROM employer_speed
ORDER BY median_reply_time ASC;

-- Общее количество найденных ответов: 749
-- employer_id работодателя с минимальной медианой: 107
-- Значение его медианы: 3.933


-- =======================================================
-- 6. Сложные типы данных
-- =======================================================

-- Это одно и то же
-- ANSI SQL-89
SELECT *
FROM calls, UNNEST(call_tags)
LIMIT 10;
-- ANSI SQL-92
SELECT *
FROM calls
CROSS JOIN UNNEST(call_tags)
LIMIT 10;

-- Изучаем

-- Смотрим все уникальные теги звонков и их частоту
SELECT 
    tag, 
    COUNT(*) AS tag_count
FROM calls
CROSS JOIN UNNEST(call_tags) AS tag -- разворачиваем массив в строки
GROUP BY tag
ORDER BY tag_count DESC;

-- Смотрим, какие вообще ключи лежат внутри message_meta
SELECT DISTINCT 
    JSONB_OBJECT_KEYS(message_meta) AS meta_keys
FROM messages;

-- Смотрим уникальные каналы и примеры того, как выглядят вложения и статус прочтения
SELECT 
    message_meta ->> 'channel' AS channel,
    message_meta ->> 'is_read' AS is_read_sample,
    message_meta -> 'attachments' AS attachments_sample,
    jsonb_typeof(message_meta -> 'attachments') AS attachments_type
FROM messages
LIMIT 10;

-- Смотрим на вложения
SELECT message_meta -> 'attachments' AS attachments_sample
FROM messages
WHERE jsonb_array_length(message_meta -> 'attachments') > 0
LIMIT 20;


-- 6.1. Теги звонков
WITH employer_calls AS (
    SELECT 
        c.call_id,
        c.status,
        c.call_tags
    FROM calls c
    JOIN responses r ON c.response_id = r.response_id
    WHERE c.caller_role = 'employer'
      AND c.response_id IS NOT NULL -- убираем наши аномалии
      AND c.call_at <= r.created_at + INTERVAL '7 days'
),
valid_calls AS (
    SELECT *
    FROM employer_calls
    -- исключаем логические противоречия между статусом и тегами
    WHERE NOT (
        (status = 'successful' AND call_tags && ARRAY['no_answer', 'technical_error']) OR
        (status != 'successful' AND call_tags && ARRAY['connected'])
    )
)
SELECT
    COUNT(*) FILTER (WHERE 'screening' = ANY(call_tags)) AS "screening",
    COUNT(*) FILTER (WHERE 'interview' = ANY(call_tags)) AS "interview",
    COUNT(*) FILTER (WHERE 'follow_up' = ANY(call_tags)) AS "follow_up",
    COUNT(*) FILTER (WHERE 'details' = ANY(call_tags)) AS "details",
    -- звонки хотя бы с одним бизнес тегом
    COUNT(*) FILTER (WHERE call_tags && ARRAY['screening', 'interview', 'follow_up', 'details']) AS "С хотя бы одним бизнес-тегом",
    -- среднее количество тегов на звонок
    ROUND(AVG(CARDINALITY(call_tags)), 2) AS "Среднее кол-во тегов на звонок"
FROM valid_calls;

-- screening: 25
-- interview: 31
-- follow_up: 29
-- details: 23
-- Количество валидных звонков, содержащих хотя бы один из перечисленных бизнес-тегов: 108
-- Среднее количество тегов на один валидный звоно: 4


-- 6.2. Метаданные сообщений
SELECT 
    m.message_meta ->> 'channel' AS channel,
    (m.message_meta ->> 'is_read')::boolean AS is_read,
    CASE 
        WHEN jsonb_typeof(m.message_meta -> 'attachments') IS NOT NULL 
        THEN jsonb_array_length(m.message_meta -> 'attachments')
        ELSE 0 
    END AS attachments_count
FROM messages m
JOIN responses r ON m.response_id = r.response_id
WHERE m.sender_role = 'employer'
    AND m.sent_at >= r.created_at 
    AND m.sent_at <= r.created_at + INTERVAL '7 days'


WITH valid_messages AS (
    SELECT 
        COALESCE(m.message_meta ->> 'channel', 'no_channel') AS channel, -- выделяем в отдельную группу
        (m.message_meta ->> 'is_read')::boolean AS is_read,
        CASE 
            WHEN jsonb_typeof(m.message_meta -> 'attachments') IS NOT NULL 
            THEN jsonb_array_length(m.message_meta -> 'attachments')
            ELSE 0 
        END AS attachments_count
    FROM messages m
    JOIN responses r ON m.response_id = r.response_id
    WHERE m.sender_role = 'employer'
        AND m.sent_at >= r.created_at 
        AND m.sent_at <= r.created_at + INTERVAL '7 days'
)
SELECT 
    channel AS "Канал",
    COUNT(*) AS "Сообщений",
    COUNT(*) FILTER (WHERE is_read IS NOT NULL) AS "Есть статус прочтения", -- (можно так интерпретировать)
    COUNT(*) FILTER (WHERE is_read = true) AS "Прочитанных",
    COUNT(*) FILTER (WHERE is_read = false) AS "Непрочитанных",
    ROUND(
        COUNT(*) FILTER (WHERE is_read = false) * 100.0 / 
        NULLIF(COUNT(*) FILTER (WHERE is_read IS NOT NULL), 0), 
        2) AS "Доля непрочитанных",
    COUNT(*) FILTER (WHERE attachments_count > 0) AS "С вложениями",
    ROUND(
        COUNT(*) FILTER (WHERE attachments_count > 0) * 100.0 / COUNT(*), 
        2) AS "Доля с вложениями, %"
FROM valid_messages
GROUP BY channel;
-- Странно, что нету 'no_channel' - проверим

-- Проверяем наличие каналов
WITH messages AS (
    SELECT 
        COALESCE(m.message_meta ->> 'channel', 'no_channel') AS channel
    FROM messages m
    JOIN responses r ON m.response_id = r.response_id
)
SELECT 
    channel "Канал",
    COUNT(channel) OVER () AS "Всего каналов"
FROM messages
GROUP BY channel;
-- Сообщений вообще без каналов не существует даже не в границах 7 дней для работодателей

-- Контрольные значения по всем получившимся каналам.
-- Канал: web
-- Сообщений: 628
-- Прочитанных: 576
-- Непрочитанных: 52
-- Доля непрочитанных: 8.28%
-- Сообщений с вложениями: 25
-- Доля с вложениями: 3.98%

-- Канал: mobile_app
-- Сообщений: 360
-- Прочитанных: 324
-- Непрочитанных: 36
-- Доля непрочитанных: 10.00%
-- Сообщений с вложениями: 14
-- Доля с вложениями: 3.89%


-- =======================================================
-- 7. Что связано с приглашением?
-- =======================================================

-- Гипотеза 1. О доступности соискателя:
-- Чаще приглашают тех кандидатов, которые отвечают на звонки и быстрее отвечают на сообщения
-- Мы ожидаем, что по приглашенным откликам процент успешных звонков выше, а если общение идет в чате,
-- то соискатели быстрее отвечают на сообщения работодателя.

-- Гипотеза 2. О взаимности:
-- Приглашение - это результат взаимного контакта, то есть и работодатель и соискатель заинтересованы в приглашении.
-- Ожидаем, что отклики, где соискатель написал хотя бы одно ответное сообщение, заканчиваются приглашением чаще, чем те, где активен только работодатель.

-- Гипотеза 1.
-- Считаем статистику дозвона по звонкам работодателя
WITH call_stats AS (
    SELECT 
        c.response_id,
        COUNT(c.call_id) AS total_calls,
        COUNT(c.call_id) FILTER (WHERE c.status = 'successful') AS successful_calls
    FROM calls c
    JOIN responses r ON c.response_id = r.response_id
    WHERE c.caller_role = 'employer' AND c.call_at <= r.created_at + INTERVAL '7 days'
    GROUP BY c.response_id
),
-- Находим время ответа кандидата на сообщения работодателя
msg_lag AS (
    SELECT 
        m.response_id,
        m.sent_at,
        m.sender_role,
        LAG(m.sender_role) OVER (PARTITION BY m.response_id ORDER BY m.sent_at, m.message_id) AS prev_role,
        LAG(m.sent_at) OVER (PARTITION BY m.response_id ORDER BY m.sent_at, m.message_id) AS prev_sent_at
    FROM messages m
    JOIN responses r ON m.response_id = r.response_id
    WHERE m.sent_at <= r.created_at + INTERVAL '7 days'
),
applicant_reply_speed AS (
    SELECT 
        response_id,
        -- Считаем медиану скорости ответа в часах для каждого отклика
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (sent_at - prev_sent_at))/3600.0) AS median_reply_hours
    FROM msg_lag
    WHERE sender_role = 'applicant' AND prev_role = 'employer'
    GROUP BY response_id
),
-- Собираем метрики по когортам из showcase
research_base AS (
    SELECT 
        s.response_id,
        CASE WHEN s.status = 'invited' THEN 'Приглашенные' ELSE 'Остальные' END AS cohort,
        COALESCE(cs.successful_calls, 0) AS successful_calls,
        COALESCE(cs.total_calls, 0) AS total_calls,
        ars.median_reply_hours
    FROM showcase s
    LEFT JOIN call_stats cs ON s.response_id = cs.response_id
    LEFT JOIN applicant_reply_speed ars ON s.response_id = ars.response_id
    -- Берем только отклики, где общение вообще началось
    WHERE s.first_event_type IS NOT NULL
)
-- Итоговый расчет для первой гипотезы
SELECT 
    cohort AS "Когорта",
    COUNT(response_id) AS "Количество откликов",
    -- Метрика 1: Процент успешных звонков
    ROUND(
        SUM(successful_calls) * 100.0 / NULLIF(SUM(total_calls), 0), 
        2
    ) AS "Доля дозвона",
    -- Метрика 2: Скорость ответа кандидата
    ROUND(AVG(median_reply_hours)::numeric, 2) AS "Среднее время ответа кандидата"
FROM research_base
GROUP BY cohort;


-- Гипотеза 1: подтверждается частично.
-- Кандидаты, получившие приглашение, действительно чаще берут трубку:
-- доля успешных звонков среди приглашенных составила 80.00% против 70.97% у остальных.
-- И скорость ответа в чате отличается, но не сильно: медиана 5.73 ч. против 6.26 ч.
-- Расчет произведен с 54 приглашенных и 328 остальных откликов.
-- Частично, потому что нужно смотреть на статистические показатели, которые бы сказали о достоверности отличия

-- Гипотеза 2.
WITH applicant_messages AS (
    SELECT 
        m.response_id,
        COUNT(m.message_id) AS app_msg_count
    FROM messages m
    JOIN responses r ON m.response_id = r.response_id
    WHERE m.sender_role = 'applicant' AND m.sent_at <= r.created_at + INTERVAL '7 days'
    GROUP BY m.response_id
),
cohorts AS (
    SELECT 
        s.response_id,
        CASE 
            WHEN s.status = 'invited' THEN 'Приглашенные' 
            ELSE 'Остальные' 
        END AS cohort,
        -- Если есть сообщения от соискателя, то ставим 1
        CASE 
            WHEN am.app_msg_count > 0 THEN 1 
            ELSE 0 
        END AS has_applicant_reply
    FROM showcase s
    LEFT JOIN applicant_messages am ON s.response_id = am.response_id
    -- Берем только отклики, где общение вообще началось
    WHERE s.first_event_type IS NOT NULL
)
SELECT 
    cohort AS "Когорта",
    COUNT(response_id) AS "Количество откликов",
    ROUND(AVG(has_applicant_reply) * 100.0, 2) AS "Кандидат ответил"
FROM cohorts
GROUP BY cohort;

-- Гипотеза 2: Не подтверждается. 
-- Наличие ответа от кандидата не является маркером приглашения.
-- Среди приглашенных откликов кандидат ответил в 87.04% случаев, тогда как в группе остальных - 90.55%.
-- Возможно это связано с тем, что при отказах кандидаты задают уточняющие вопросы, а при успешном 
-- контакте коммуникация быстро переходит за пределы платформы.


-- =======================================================
-- 8. Итог исследования
-- =======================================================

-- В первые 7 дней после отклика работодатели выходят на связь по 382 из 628 откликов, а остальные 246 откликов остаются вообще без реакции.
-- Основной канал взаимодействия - переписка (988 сообщений против 108 звонков), причем первый контакт почти всегда происходит в чате 
--  (314 откликов против 68 со звонка), чаще идет через web-интерфейс (628 сообщений из 988) и имеет высокую читаемость 
--  (непрочитанными остаются только 8.28% в web и 10.00% в mobile_app).
-- Звонки работодатели подключают точечно под конкретные задачи (чаще всего с тегами interview - 31 и follow_up - 29), а типичный успшеный 
--  разговор длится по медиане 438 секнд.
-- Подход к обработке откликов сильно зависит от направления и компании: например, у аналитиков данных и тестировщиков лидеры рейтинга
--  обрабатывают 88-89% откликов, тогда как у дата-инженеров уже на 2 месте доля падает до 45.83%.
-- Скорость реакции работодателей тоже различается, в активной переписке самый быстрый работодатель (id 107) отвечает кандидату по медиане за 3.93 часа.
-- Сравнение 54 приглашенных откликов с 328 остальными (где была коммуникация) показало, что приглашение связано с телефонной доступностью соискателя: 
--  доля успешных дозвонов по приглашенным составила 80.00% против 70.97% у остальных и скорость ответа кандидата в чате немного отличается (5.73 ч против 6.26 ч).
-- Сам факт ответа соискателя в чате не является маркером приглашения (среди приглашенных ответили 87.04% против 90.55% у остальных), 
--  и здесь важно отделять корреляцию от причинной связи: возможно, с подходящими кандидатами общение быстрее уходит во внешние мессенджеры или звонки,
--  а при отказах люди чаще могут писать уточняющие вопросы в чат.
-- Ограничение проведенного анализа в том, что мы не знаем точное время смены статуса на invited (произошло ли приглашение в результате общения или до него), 
--  смотрим только на окно в 7 дней на небольшой выборке (54 приглашения)
--  и были вынуждены отбросить 8 звонков, потерявших привязку к response_id.
--  Данные несколько синтетические и, поэтому не во всем похожи на настоящие: в самом начале мы увидели, что у отклика либо 0, либо 6 сообщений, 
--  что не сочетается с реальностью.
-- Следующим шагом я бы запросил у разработчиков историю смены статусов отклика со временем и оценку соответствия резюме вакансии, чтобы проверить,
--  является ли приглашение следствием активного диалога или решения принимаются еще на этапе просмотра резюме (а еще информацию о потерявшихся response_id).
