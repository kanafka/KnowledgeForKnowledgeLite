-- ============================================
-- Группировка запросов в транзакции
-- KnowledgeForKnowledgeLite
-- 
-- Описание: Этот файл содержит все транзакции для обеспечения атомарности
-- критических операций в системе.
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

START TRANSACTION;

-- Вставка аккаунта
INSERT INTO Accounts (Login, PasswordHash, EmailConfirmed, CreatedAt)
VALUES ('newstudent@university.edu', '$2b$10$hashedpassword', FALSE, NOW());

SET @new_account_id = LAST_INSERT_ID();

-- Создание профиля
INSERT INTO UserProfiles (AccountID, FullName, IsActive, CreatedAt)
VALUES (@new_account_id, 'Новый Студент', TRUE, NOW());

-- Логирование
INSERT INTO AuditLog (ActorAccountID, Action, EntityType, EntityID, Result, CreatedAt)
VALUES (@new_account_id, 'UserRegistered', 'Account', @new_account_id, 'Success', NOW());

COMMIT;
-- В случае ошибки: ROLLBACK;

-- ============================================
-- 11.2. Транзакция добавления навыка с документом
-- ============================================
-- Описание: Атомарное добавление навыка, загрузка документа и создание запроса на верификацию
-- Использование: Когда пользователь добавляет навык и сразу загружает подтверждающий документ

START TRANSACTION;

SET @account_id = 1;
SET @skill_id = (SELECT SkillID FROM SkillsCatalog WHERE SkillName = 'Python Programming');
SET @level_id = (SELECT LevelID FROM SkillLevels WHERE Name = 'Intermediate');

-- Добавление навыка
INSERT INTO UserSkills (AccountID, SkillID, SkillLevelID, IsVerified, ExperienceYears, CreatedAt)
VALUES (@account_id, @skill_id, @level_id, FALSE, 2.0, NOW())
ON DUPLICATE KEY UPDATE
    SkillLevelID = @level_id,
    ExperienceYears = 2.0,
    UpdatedAt = NOW();

SET @user_skill_id = LAST_INSERT_ID();

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
    @account_id,
    @skill_id,
    'https://storage.example.com/proofs/cert_123.pdf',
    'Python_Certificate.pdf',
    1024000,
    'application/pdf',
    'Pending',
    NOW()
);

SET @proof_id = LAST_INSERT_ID();

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
    @account_id,
    @proof_id,
    'SkillVerification',
    'Pending',
    'Прошу верифицировать мой сертификат по Python',
    NOW()
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
    @account_id,
    'SkillAddedWithProof',
    'UserSkill',
    @user_skill_id,
    JSON_OBJECT('SkillID', @skill_id, 'ProofID', @proof_id),
    'Success',
    NOW()
);

COMMIT;

-- ============================================
-- 11.3. Транзакция верификации документа администратором
-- ============================================
-- Описание: Атомарная верификация документа с обновлением статуса навыка и запроса на верификацию
-- Использование: Когда администратор проверяет и одобряет/отклоняет документ

START TRANSACTION;

SET @proof_id = 1;
SET @admin_id = 999;
SET @decision = 'Approved'; -- или 'Rejected'

-- Обновление статуса документа
UPDATE Proofs
SET Status = @decision,
    VerifiedBy = @admin_id,
    VerifiedAt = NOW(),
    UpdatedAt = NOW()
WHERE ProofID = @proof_id;

-- Если одобрено, обновляем навык пользователя
IF @decision = 'Approved' THEN
    UPDATE UserSkills
    SET IsVerified = TRUE,
        VerifiedAt = NOW(),
        UpdatedAt = NOW()
    WHERE AccountID = (SELECT AccountID FROM Proofs WHERE ProofID = @proof_id)
      AND SkillID = (SELECT SkillID FROM Proofs WHERE ProofID = @proof_id)
      AND SkillID IS NOT NULL;
END IF;

-- Обновление запроса на верификацию
UPDATE VerificationRequests
SET Status = @decision,
    ReviewedBy = @admin_id,
    ReviewedAt = NOW(),
    ReviewNotes = CONCAT('Документ проверен и ', LOWER(@decision)),
    UpdatedAt = NOW()
WHERE ProofID = @proof_id
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
    @admin_id,
    'ProofVerified',
    'Proof',
    @proof_id,
    JSON_OBJECT('Decision', @decision, 'ProofID', @proof_id),
    'Success',
    NOW()
);

COMMIT;

-- ============================================
-- 11.4. Транзакция публикации поста с увеличением счетчика просмотров
-- ============================================
-- Описание: Атомарное увеличение счетчика просмотров и логирование события
-- Использование: При просмотре поста пользователем

START TRANSACTION;

SET @post_id = 1;

-- Увеличение счетчика просмотров (оптимистическая блокировка)
UPDATE SkillPosts
SET ViewsCount = ViewsCount + 1,
    UpdatedAt = NOW()
WHERE PostID = @post_id
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
    @post_id,
    'Success',
    NOW()
);

COMMIT;

-- ============================================
-- 11.5. Транзакция удаления пользователя (мягкое удаление)
-- ============================================
-- Описание: Атомарное мягкое удаление пользователя с деактивацией профиля и закрытием постов
-- Использование: При удалении аккаунта пользователя

START TRANSACTION;

SET @account_id = 1;

-- Мягкое удаление аккаунта
UPDATE Accounts
SET DeletedAt = NOW(),
    UpdatedAt = NOW()
WHERE AccountID = @account_id
  AND DeletedAt IS NULL;

-- Деактивация профиля
UPDATE UserProfiles
SET IsActive = FALSE,
    UpdatedAt = NOW()
WHERE AccountID = @account_id;

-- Закрытие всех активных постов пользователя
UPDATE SkillPosts
SET Status = 'Closed',
    DeletedAt = NOW(),
    UpdatedAt = NOW()
WHERE AccountID = @account_id
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
    @account_id,
    'AccountDeleted',
    'Account',
    @account_id,
    'Success',
    NOW()
);

COMMIT;

-- ============================================
-- 11.6. Транзакция поиска партнеров для обмена знаниями
-- ============================================
-- Описание: Поиск пользователей для обмена знаниями и логирование поиска
-- Использование: Когда пользователь ищет партнеров для взаимопомощи

START TRANSACTION;

-- Поиск пользователей, которые ищут навык A и предлагают навык B
SET @requested_skill = 'Mathematical Analysis';
SET @offered_skill = 'Linear Algebra';
SET @user_id = 1;

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
  AND sp_request.SkillID = (SELECT SkillID FROM SkillsCatalog WHERE SkillName = @requested_skill)
  AND sp_request.Status = 'Active'
  AND sp_request.DeletedAt IS NULL
  AND sp_offer.PostType = 'Offer'
  AND sp_offer.SkillID = (SELECT SkillID FROM SkillsCatalog WHERE SkillName = @offered_skill)
  AND sp_offer.Status = 'Active'
  AND sp_offer.DeletedAt IS NULL
  AND a.DeletedAt IS NULL
  AND up.IsActive = TRUE
  AND sp_request.AccountID != @user_id
ORDER BY sp_request.CreatedAt DESC
LIMIT 10;

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
    @user_id,
    'PartnerSearch',
    'Search',
    NULL,
    JSON_OBJECT('RequestedSkill', @requested_skill, 'OfferedSkill', @offered_skill),
    'Success',
    NOW()
);

COMMIT;

-- ============================================
-- Конец файла
-- ============================================

