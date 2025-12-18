-- ============================================
-- SQL DML запросы, реализующие функциональные требования
-- KnowledgeForKnowledgeLite
-- 
-- Описание: Этот файл содержит все DML запросы (SELECT, INSERT, UPDATE, DELETE),
-- необходимые для реализации функциональных требований системы.
-- 
-- Разделы соответствуют разделам из пояснительной записки (раздел 10)
-- ============================================

-- ============================================
-- 10.1. Управление пользователями (FR-1, FR-2, FR-4, FR-5)
-- ============================================

-- FR-1: Регистрация нового пользователя
-- Описание: Создание новой учетной записи и профиля пользователя
-- Использование: Выполнить в транзакции для обеспечения атомарности

-- Шаг 1: Регистрация пользователя
INSERT INTO Accounts (Login, PasswordHash, EmailConfirmed, CreatedAt)
VALUES ('student@university.edu', '$2b$10$hashedpassword', FALSE, NOW());

-- Шаг 2: Создание профиля при регистрации
INSERT INTO UserProfiles (AccountID, FullName, IsActive, CreatedAt)
VALUES (LAST_INSERT_ID(), 'Иван Иванов', TRUE, NOW());

-- ============================================

-- FR-2: Аутентификация пользователя
-- Описание: Проверка логина и получение данных для аутентификации
-- Примечание: Хэш пароля проверяется в приложении (BCrypt)

SELECT AccountID, Login, PasswordHash, IsAdmin, EmailConfirmed, DeletedAt
FROM Accounts
WHERE Login = 'student@university.edu' 
  AND DeletedAt IS NULL;

-- ============================================

-- FR-5: Обновление времени последнего входа
-- Описание: Обновление времени последнего успешного входа пользователя

UPDATE Accounts
SET LastLoginAt = NOW()
WHERE AccountID = 1;

-- ============================================

-- FR-4: Мягкое удаление пользователя
-- Описание: Мягкое удаление (soft delete) пользователя
-- Примечание: Для полного удаления используется транзакция (см. transactions.sql)

UPDATE Accounts
SET DeletedAt = NOW()
WHERE AccountID = 1;

-- ============================================
-- 10.2. Управление профилями (FR-6, FR-7, FR-8)
-- ============================================

-- FR-6: Создание/редактирование профиля
-- Описание: Обновление информации профиля пользователя

UPDATE UserProfiles
SET FullName = 'Иван Петров',
    DateOfBirth = '2000-01-15',
    PhotoURL = 'https://example.com/photo.jpg',
    Description = 'Студент 3 курса, изучаю программирование',
    UpdatedAt = NOW()
WHERE AccountID = 1;

-- ============================================

-- FR-7: Добавление контакта с настройкой видимости
-- Описание: Добавление контактной информации пользователя с указанием публичности

INSERT INTO UserContacts (AccountID, ContactType, ContactValue, IsPublic, DisplayOrder)
VALUES (1, 'Email', 'ivan@example.com', TRUE, 1),
       (1, 'Telegram', '@ivan_petrov', TRUE, 2),
       (1, 'Phone', '+7-900-123-45-67', FALSE, 3);

-- ============================================

-- FR-8: Обновление времени последнего визита
-- Описание: Обновление времени последнего визита пользователя

UPDATE UserProfiles
SET LastSeenOnline = NOW()
WHERE AccountID = 1;

-- ============================================
-- 10.3. Управление навыками (FR-9, FR-10, FR-11, FR-12, FR-13)
-- ============================================

-- FR-10: Добавление навыка пользователю
-- Описание: Добавление навыка пользователю с указанием уровня владения
-- Примечание: Использует ON DUPLICATE KEY UPDATE для обновления при дубликате

-- Шаг 1: Получение SkillID и LevelID
SET @skill_id = (SELECT SkillID FROM SkillsCatalog WHERE SkillName = 'Python Programming');
SET @level_id = (SELECT LevelID FROM SkillLevels WHERE Name = 'Intermediate');

-- Шаг 2: Добавление навыка
INSERT INTO UserSkills (AccountID, SkillID, SkillLevelID, IsVerified, ExperienceYears, CreatedAt)
VALUES (1, @skill_id, @level_id, FALSE, 2.5, NOW())
ON DUPLICATE KEY UPDATE
    SkillLevelID = @level_id,
    ExperienceYears = 2.5,
    UpdatedAt = NOW();

-- ============================================

-- FR-13: Получение всех навыков пользователя
-- Описание: Получение списка всех навыков пользователя с информацией о категории и уровне

SELECT 
    sc.SkillName,
    sc.Description AS SkillDescription,
    cat.Name AS CategoryName,
    sl.Name AS LevelName,
    sl.Rank AS LevelRank,
    us.IsVerified,
    us.ExperienceYears,
    us.CreatedAt AS AddedAt
FROM UserSkills us
JOIN SkillsCatalog sc ON us.SkillID = sc.SkillID
JOIN SkillCategories cat ON sc.CategoryID = cat.CategoryID
JOIN SkillLevels sl ON us.SkillLevelID = sl.LevelID
WHERE us.AccountID = 1
ORDER BY cat.DisplayOrder, sc.SkillName;

-- ============================================
-- 10.4. Верификация навыков (FR-15, FR-16, FR-17, FR-18)
-- ============================================

-- FR-15: Загрузка подтверждающего документа
-- Описание: Добавление документа, подтверждающего навык пользователя

SET @skill_id = (SELECT SkillID FROM SkillsCatalog WHERE SkillName = 'Python Programming');

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
    1, 
    @skill_id, 
    'https://storage.example.com/proofs/certificate_123.pdf',
    'Python_Certificate.pdf',
    2048576,
    'application/pdf',
    'Pending',
    NOW()
);

-- ============================================

-- FR-16: Верификация документа администратором
-- Описание: Верификация документа администратором и обновление статуса навыка
-- Примечание: Для полной верификации используется транзакция (см. transactions.sql)

-- Шаг 1: Обновление статуса документа
UPDATE Proofs
SET Status = 'Approved',
    VerifiedBy = 999, -- ID администратора
    VerifiedAt = NOW(),
    UpdatedAt = NOW()
WHERE ProofID = 1;

-- Шаг 2: Обновление статуса навыка пользователя
UPDATE UserSkills
SET IsVerified = TRUE,
    VerifiedAt = NOW(),
    UpdatedAt = NOW()
WHERE AccountID = 1 
  AND SkillID = (SELECT SkillID FROM Proofs WHERE ProofID = 1);

-- ============================================

-- FR-17: Получение информации о верификаторе
-- Описание: Получение информации о том, кто и когда верифицировал документ

SELECT 
    p.ProofID,
    p.FileName,
    p.Status,
    p.VerifiedAt,
    a.Login AS VerifiedByLogin,
    up.FullName AS VerifiedByName
FROM Proofs p
LEFT JOIN Accounts a ON p.VerifiedBy = a.AccountID
LEFT JOIN UserProfiles up ON a.AccountID = up.AccountID
WHERE p.ProofID = 1;

-- ============================================
-- 10.5. Образование (FR-20)
-- ============================================

-- FR-20: Добавление информации об образовании
-- Описание: Добавление записи об образовании пользователя

INSERT INTO Education (
    AccountID,
    InstitutionName,
    DegreeField,
    YearStarted,
    YearCompleted,
    DegreeLevel,
    IsCurrent,
    CreatedAt
)
VALUES (
    1,
    'Московский Государственный Университет',
    'Прикладная математика и информатика',
    2018,
    2022,
    'Bachelor',
    FALSE,
    NOW()
);

-- ============================================
-- 10.6. Публикация предложений и запросов (FR-21, FR-22, FR-23, FR-24)
-- ============================================

-- FR-21: Публикация предложения (Offer)
-- Описание: Создание поста с предложением помощи по навыку

SET @skill_id = (SELECT SkillID FROM SkillsCatalog WHERE SkillName = 'Linear Algebra');

INSERT INTO SkillPosts (
    AccountID,
    SkillID,
    PostType,
    Title,
    Details,
    Status,
    ContactPreference,
    ExpiresAt,
    CreatedAt
)
VALUES (
    1,
    @skill_id,
    'Offer',
    'Помощь с линейной алгеброй',
    'Готов помочь с решением задач по линейной алгебре. Изучаю предмет на отлично, могу объяснить сложные темы простым языком.',
    'Active',
    'Telegram',
    DATE_ADD(NOW(), INTERVAL 30 DAY),
    NOW()
);

-- ============================================

-- FR-22: Публикация запроса (Request)
-- Описание: Создание поста с запросом помощи по навыку

SET @skill_id = (SELECT SkillID FROM SkillsCatalog WHERE SkillName = 'Mathematical Analysis');

INSERT INTO SkillPosts (
    AccountID,
    SkillID,
    PostType,
    Title,
    Details,
    Status,
    ContactPreference,
    ExpiresAt,
    CreatedAt
)
VALUES (
    2,
    @skill_id,
    'Request',
    'Нужна помощь с математическим анализом',
    'Ищу студента, который хорошо разбирается в матанализе и готов помочь с подготовкой к экзамену. Взамен могу помочь с программированием на Python.',
    'Active',
    'Email',
    DATE_ADD(NOW(), INTERVAL 14 DAY),
    NOW()
);

-- ============================================

-- FR-23: Поиск предложений и запросов по навыку
-- Описание: Поиск активных предложений по определенному навыку

SELECT 
    sp.PostID,
    sp.PostType,
    sp.Title,
    sp.Details,
    sp.ContactPreference,
    sp.CreatedAt,
    up.FullName AS AuthorName,
    sc.SkillName,
    sl.Name AS AuthorSkillLevel
FROM SkillPosts sp
JOIN Accounts a ON sp.AccountID = a.AccountID
JOIN UserProfiles up ON a.AccountID = up.AccountID
JOIN SkillsCatalog sc ON sp.SkillID = sc.SkillID
LEFT JOIN UserSkills us ON a.AccountID = us.AccountID AND sp.SkillID = us.SkillID
LEFT JOIN SkillLevels sl ON us.SkillLevelID = sl.LevelID
WHERE sp.SkillID = (SELECT SkillID FROM SkillsCatalog WHERE SkillName = 'Linear Algebra')
  AND sp.Status = 'Active'
  AND sp.DeletedAt IS NULL
  AND sp.PostType = 'Offer'
ORDER BY sp.CreatedAt DESC;

-- ============================================

-- FR-24: Изменение статуса поста
-- Описание: Изменение статуса поста (например, закрытие)

UPDATE SkillPosts
SET Status = 'Closed',
    UpdatedAt = NOW()
WHERE PostID = 1;

-- ============================================
-- 10.7. Поиск и фильтрация (FR-28, FR-29, FR-30)
-- ============================================

-- FR-28: Поиск пользователей по навыку
-- Описание: Поиск всех пользователей, владеющих определенным навыком

SELECT DISTINCT
    a.AccountID,
    up.FullName,
    up.PhotoURL,
    up.Description,
    sl.Name AS SkillLevel,
    sl.Rank AS LevelRank,
    us.IsVerified,
    us.ExperienceYears,
    up.LastSeenOnline
FROM Accounts a
JOIN UserProfiles up ON a.AccountID = up.AccountID
JOIN UserSkills us ON a.AccountID = us.AccountID
JOIN SkillsCatalog sc ON us.SkillID = sc.SkillID
JOIN SkillLevels sl ON us.SkillLevelID = sl.LevelID
WHERE sc.SkillName = 'Python Programming'
  AND a.DeletedAt IS NULL
  AND up.IsActive = TRUE
ORDER BY sl.Rank DESC, us.IsVerified DESC, up.LastSeenOnline DESC;

-- ============================================

-- FR-29: Фильтрация по уровню владения навыком
-- Описание: Поиск пользователей с определенным минимальным уровнем владения навыком

SELECT 
    a.AccountID,
    up.FullName,
    sl.Name AS SkillLevel,
    us.IsVerified
FROM Accounts a
JOIN UserProfiles up ON a.AccountID = up.AccountID
JOIN UserSkills us ON a.AccountID = us.AccountID
JOIN SkillsCatalog sc ON us.SkillID = sc.SkillID
JOIN SkillLevels sl ON us.SkillLevelID = sl.LevelID
WHERE sc.SkillName = 'Linear Algebra'
  AND sl.Rank >= 3  -- Advanced или Expert
  AND us.IsVerified = TRUE
  AND a.DeletedAt IS NULL
ORDER BY sl.Rank DESC;

-- ============================================
-- 10.8. Аудит (FR-31)
-- ============================================

-- FR-31: Логирование действий пользователей
-- Описание: Запись действий пользователей в журнал аудита

-- Пример 1: Логирование входа пользователя
INSERT INTO AuditLog (
    ActorAccountID,
    Action,
    EntityType,
    EntityID,
    IPAddress,
    UserAgent,
    Result,
    CreatedAt
)
VALUES (
    1,
    'UserLogin',
    'Account',
    1,
    '192.168.1.1',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
    'Success',
    NOW()
);

-- Пример 2: Логирование добавления навыка
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
    1,
    'SkillAdded',
    'UserSkill',
    LAST_INSERT_ID(),
    JSON_OBJECT('SkillID', 5, 'SkillName', 'Python Programming', 'Level', 'Intermediate'),
    'Success',
    NOW()
);

-- ============================================
-- Конец файла
-- ============================================

