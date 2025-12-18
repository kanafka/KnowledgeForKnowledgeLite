-- ============================================
-- Группировка запросов в транзакции для PostgreSQL
-- KnowledgeForKnowledgeLite
-- 
-- Описание: Этот файл содержит все транзакции для обеспечения атомарности
-- критических операций в системе (PostgreSQL версия).
-- 
-- Разделы соответствуют разделам из пояснительной записки (раздел 11)
-- 
-- Важно: Все транзакции должны выполняться полностью или откатываться при ошибке
-- ============================================

-- ============================================
-- 11.1. Транзакция регистрации пользователя
-- ============================================
-- Описание: Атомарное создание аккаунта, профиля и логирование события
-- Использование: При регистрации нового пользователя
-- В PostgreSQL используем RETURNING для получения ID

BEGIN;

-- Вставка аккаунта (возвращает AccountID)
DO $$
DECLARE
    new_account_id BIGINT;
BEGIN
    -- Вставка аккаунта
    INSERT INTO Accounts (Login, PasswordHash, EmailConfirmed, CreatedAt)
    VALUES ('newstudent@university.edu', '$2b$10$hashedpassword', FALSE, CURRENT_TIMESTAMP)
    RETURNING AccountID INTO new_account_id;

    -- Создание профиля
    INSERT INTO UserProfiles (AccountID, FullName, IsActive, CreatedAt)
    VALUES (new_account_id, 'Новый Студент', TRUE, CURRENT_TIMESTAMP);

    -- Логирование
    INSERT INTO AuditLog (ActorAccountID, Action, EntityType, EntityID, Result, CreatedAt)
    VALUES (new_account_id, 'UserRegistered', 'Account', new_account_id, 'Success', CURRENT_TIMESTAMP);
END $$;

COMMIT;
-- В случае ошибки: ROLLBACK;

-- ============================================
-- 11.2. Транзакция добавления навыка с документом
-- ============================================
-- Описание: Атомарное добавление навыка, загрузка документа и создание запроса на верификацию
-- Использование: Когда пользователь добавляет навык и сразу загружает подтверждающий документ

BEGIN;

DO $$
DECLARE
    account_id BIGINT := 1;
    skill_id BIGINT;
    level_id BIGINT;
    proof_id BIGINT;
BEGIN
    -- Получаем ID навыка и уровня
    SELECT SkillID INTO skill_id FROM SkillsCatalog WHERE SkillName = 'Python Programming';
    SELECT LevelID INTO level_id FROM SkillLevels WHERE Name = 'Intermediate';

    -- Добавление навыка (с обработкой конфликтов)
    INSERT INTO UserSkills (AccountID, SkillID, SkillLevelID, IsVerified, ExperienceYears, CreatedAt)
    VALUES (account_id, skill_id, level_id, FALSE, 2.0, CURRENT_TIMESTAMP)
    ON CONFLICT (AccountID, SkillID) 
    DO UPDATE SET
        SkillLevelID = EXCLUDED.SkillLevelID,
        ExperienceYears = EXCLUDED.ExperienceYears,
        UpdatedAt = CURRENT_TIMESTAMP;

    -- Загрузка документа
    INSERT INTO Proofs (
        AccountID, 
        SkillID, 
        FileURL, 
        FileName, 
        FileSize, 
        MimeType, 
        Status,
        CreatedAt
    )
    VALUES (
        account_id,
        skill_id,
        'https://storage.example.com/proofs/cert_123.pdf',
        'Python_Certificate.pdf',
        1024000,
        'application/pdf',
        'Pending',
        CURRENT_TIMESTAMP
    )
    RETURNING ProofID INTO proof_id;

    -- Создание запроса на верификацию
    INSERT INTO VerificationRequests (
        AccountID,
        ProofID,
        RequestType,
        Status,
        RequestMessage,
        CreatedAt
    )
    VALUES (
        account_id,
        proof_id,
        'SkillVerification',
        'Pending',
        'Прошу верифицировать мой сертификат по Python',
        CURRENT_TIMESTAMP
    );

    -- Логирование
    INSERT INTO AuditLog (
        ActorAccountID,
        Action,
        EntityType,
        EntityID,
        Details,
        Result,
        CreatedAt
    )
    VALUES (
        account_id,
        'SkillAddedWithProof',
        'UserSkill',
        (SELECT ContactID FROM UserContacts WHERE AccountID = account_id LIMIT 1), -- пример
        jsonb_build_object('SkillID', skill_id, 'ProofID', proof_id),
        'Success',
        CURRENT_TIMESTAMP
    );
END $$;

COMMIT;

-- ============================================
-- 11.3. Транзакция верификации документа администратором
-- ============================================
-- Описание: Атомарная верификация документа с обновлением статуса навыка и запроса на верификацию
-- Использование: Когда администратор проверяет и одобряет/отклоняет документ

BEGIN;

DO $$
DECLARE
    proof_id BIGINT := 1;
    admin_id BIGINT := 999;
    decision VARCHAR(20) := 'Approved'; -- или 'Rejected'
    account_id_val BIGINT;
    skill_id_val BIGINT;
BEGIN
    -- Получаем данные документа
    SELECT AccountID, SkillID INTO account_id_val, skill_id_val 
    FROM Proofs 
    WHERE ProofID = proof_id;

    -- Обновление статуса документа
    UPDATE Proofs
    SET Status = decision,
        VerifiedBy = admin_id,
        VerifiedAt = CURRENT_TIMESTAMP,
        UpdatedAt = CURRENT_TIMESTAMP
    WHERE ProofID = proof_id;

    -- Если одобрено, обновляем навык пользователя
    IF decision = 'Approved' AND skill_id_val IS NOT NULL THEN
        UPDATE UserSkills
        SET IsVerified = TRUE,
            VerifiedAt = CURRENT_TIMESTAMP,
            UpdatedAt = CURRENT_TIMESTAMP
        WHERE AccountID = account_id_val
          AND SkillID = skill_id_val;
    END IF;

    -- Обновление запроса на верификацию
    UPDATE VerificationRequests
    SET Status = decision,
        ReviewedBy = admin_id,
        ReviewedAt = CURRENT_TIMESTAMP,
        ReviewNotes = CONCAT('Документ проверен и ', LOWER(decision)),
        UpdatedAt = CURRENT_TIMESTAMP
    WHERE ProofID = proof_id
      AND Status = 'Pending';

    -- Логирование
    INSERT INTO AuditLog (
        ActorAccountID,
        Action,
        EntityType,
        EntityID,
        Details,
        Result,
        CreatedAt
    )
    VALUES (
        admin_id,
        'ProofVerified',
        'Proof',
        proof_id,
        jsonb_build_object('Decision', decision, 'ProofID', proof_id),
        'Success',
        CURRENT_TIMESTAMP
    );
END $$;

COMMIT;

-- ============================================
-- 11.4. Транзакция публикации поста с увеличением счетчика просмотров
-- ============================================
-- Описание: Атомарное увеличение счетчика просмотров и логирование события
-- Использование: При просмотре поста пользователем

BEGIN;

DO $$
DECLARE
    post_id_val BIGINT := 1;
BEGIN
    -- Увеличение счетчика просмотров
    UPDATE SkillPosts
    SET ViewsCount = ViewsCount + 1,
        UpdatedAt = CURRENT_TIMESTAMP
    WHERE PostID = post_id_val
      AND DeletedAt IS NULL;

    -- Логирование просмотра
    INSERT INTO AuditLog (
        ActorAccountID,
        Action,
        EntityType,
        EntityID,
        Result,
        CreatedAt
    )
    VALUES (
        NULL, -- может быть NULL для гостевых просмотров
        'PostViewed',
        'SkillPost',
        post_id_val,
        'Success',
        CURRENT_TIMESTAMP
    );
END $$;

COMMIT;

-- ============================================
-- 11.5. Транзакция удаления пользователя (мягкое удаление)
-- ============================================
-- Описание: Атомарное мягкое удаление пользователя с деактивацией профиля и закрытием постов
-- Использование: При удалении аккаунта пользователя

BEGIN;

DO $$
DECLARE
    account_id_val BIGINT := 1;
BEGIN
    -- Мягкое удаление аккаунта
    UPDATE Accounts
    SET DeletedAt = CURRENT_TIMESTAMP,
        UpdatedAt = CURRENT_TIMESTAMP
    WHERE AccountID = account_id_val
      AND DeletedAt IS NULL;

    -- Деактивация профиля
    UPDATE UserProfiles
    SET IsActive = FALSE,
        UpdatedAt = CURRENT_TIMESTAMP
    WHERE AccountID = account_id_val;

    -- Закрытие всех активных постов пользователя
    UPDATE SkillPosts
    SET Status = 'Closed',
        DeletedAt = CURRENT_TIMESTAMP,
        UpdatedAt = CURRENT_TIMESTAMP
    WHERE AccountID = account_id_val
      AND Status = 'Active'
      AND DeletedAt IS NULL;

    -- Логирование
    INSERT INTO AuditLog (
        ActorAccountID,
        Action,
        EntityType,
        EntityID,
        Result,
        CreatedAt
    )
    VALUES (
        account_id_val,
        'AccountDeleted',
        'Account',
        account_id_val,
        'Success',
        CURRENT_TIMESTAMP
    );
END $$;

COMMIT;

-- ============================================
-- 11.6. Транзакция поиска партнеров для обмена знаниями
-- ============================================
-- Описание: Поиск пользователей для обмена знаниями и логирование поиска
-- Использование: Когда пользователь ищет партнеров для взаимопомощи

BEGIN;

DO $$
DECLARE
    requested_skill VARCHAR(100) := 'Mathematical Analysis';
    offered_skill VARCHAR(100) := 'Linear Algebra';
    user_id_val BIGINT := 1;
BEGIN
    -- Поиск пользователей, которые:
    -- 1. Ищут помощь с запрошенным навыком (Request)
    -- 2. Предлагают помощь с предлагаемым навыком (Offer)
    -- Примечание: SELECT запрос выполняется внутри транзакции для логирования
    
    -- Логирование поиска
    INSERT INTO AuditLog (
        ActorAccountID,
        Action,
        EntityType,
        EntityID,
        Details,
        Result,
        CreatedAt
    )
    VALUES (
        user_id_val,
        'PartnerSearch',
        'Search',
        NULL,
        jsonb_build_object('RequestedSkill', requested_skill, 'OfferedSkill', offered_skill),
        'Success',
        CURRENT_TIMESTAMP
    );
END $$;

-- Пример SELECT запроса для поиска партнеров (выполняется отдельно)
-- Находим пользователей, которые:
-- 1. Ищут помощь с запрошенным навыком (Request)
-- 2. Предлагают помощь с предлагаемым навыком (Offer)
SELECT 
    sp_request.AccountID AS PartnerID,
    up.FullName AS PartnerName,
    up.Description AS PartnerDescription,
    sp_request.Title AS RequestTitle,
    sp_offer.Title AS OfferTitle,
    uc_public.ContactValue AS Contact
FROM SkillPosts sp_request
JOIN Accounts a ON sp_request.AccountID = a.AccountID
JOIN UserProfiles up ON a.AccountID = up.AccountID
JOIN SkillPosts sp_offer ON sp_request.AccountID = sp_offer.AccountID
LEFT JOIN UserContacts uc_public ON a.AccountID = uc_public.AccountID 
    AND uc_public.IsPublic = TRUE 
    AND uc_public.ContactType = 'Email'
WHERE sp_request.PostType = 'Request'
  AND sp_request.SkillID = (SELECT SkillID FROM SkillsCatalog WHERE SkillName = 'Mathematical Analysis')
  AND sp_request.Status = 'Active'
  AND sp_request.DeletedAt IS NULL
  AND sp_offer.PostType = 'Offer'
  AND sp_offer.SkillID = (SELECT SkillID FROM SkillsCatalog WHERE SkillName = 'Linear Algebra')
  AND sp_offer.Status = 'Active'
  AND sp_offer.DeletedAt IS NULL
  AND a.DeletedAt IS NULL
  AND up.IsActive = TRUE
  AND sp_request.AccountID != 1
ORDER BY sp_request.CreatedAt DESC
LIMIT 10;

COMMIT;

-- ============================================
-- Конец файла
-- ============================================


