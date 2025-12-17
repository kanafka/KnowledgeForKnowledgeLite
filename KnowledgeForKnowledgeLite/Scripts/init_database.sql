-- ============================================
-- Скрипт инициализации базы данных
-- KnowledgeForKnowledgeLite
-- ============================================

-- Создание базы данных
CREATE DATABASE IF NOT EXISTS KnowledgeForKnowledgeLite CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE KnowledgeForKnowledgeLite;

-- Удаление существующих таблиц (в обратном порядке зависимостей)
DROP TABLE IF EXISTS AuditLog;
DROP TABLE IF EXISTS VerificationRequests;
DROP TABLE IF EXISTS SkillPosts;
DROP TABLE IF EXISTS Proofs;
DROP TABLE IF EXISTS Education;
DROP TABLE IF EXISTS UserSkills;
DROP TABLE IF EXISTS UserContacts;
DROP TABLE IF EXISTS UserProfiles;
DROP TABLE IF EXISTS SkillsCatalog;
DROP TABLE IF EXISTS SkillLevels;
DROP TABLE IF EXISTS SkillCategories;
DROP TABLE IF EXISTS Accounts;

-- ============================================
-- 1. Таблица Accounts (Аккаунты)
-- ============================================
CREATE TABLE Accounts (
    AccountID BIGINT PRIMARY KEY AUTO_INCREMENT,
    Login VARCHAR(100) NOT NULL UNIQUE,
    PasswordHash VARCHAR(255) NOT NULL,
    IsAdmin BOOLEAN NOT NULL DEFAULT FALSE,
    EmailConfirmed BOOLEAN NOT NULL DEFAULT FALSE,
    LastLoginAt DATETIME NULL,
    PasswordUpdatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CreatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    DeletedAt DATETIME NULL,
    
    INDEX idx_accounts_deleted_at (DeletedAt),
    INDEX idx_accounts_is_admin (IsAdmin)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- 2. Таблица UserProfiles (Профили пользователей)
-- ============================================
CREATE TABLE UserProfiles (
    AccountID BIGINT PRIMARY KEY,
    FullName VARCHAR(150) NULL,
    DateOfBirth DATE NULL,
    PhotoURL VARCHAR(500) NULL,
    Description TEXT NULL,
    LastSeenOnline DATETIME NULL,
    IsActive BOOLEAN NOT NULL DEFAULT TRUE,
    CreatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_user_profiles_description_length 
        CHECK (LENGTH(Description) <= 3000),
    CONSTRAINT fk_user_profiles_account 
        FOREIGN KEY (AccountID) REFERENCES Accounts(AccountID) 
        ON DELETE CASCADE,
    
    INDEX idx_user_profiles_full_name (FullName),
    INDEX idx_user_profiles_is_active (IsActive)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- 3. Таблица UserContacts (Контакты)
-- ============================================
CREATE TABLE UserContacts (
    ContactID BIGINT PRIMARY KEY AUTO_INCREMENT,
    AccountID BIGINT NOT NULL,
    ContactType VARCHAR(50) NOT NULL,
    ContactValue VARCHAR(255) NOT NULL,
    IsPublic BOOLEAN NOT NULL DEFAULT FALSE,
    DisplayOrder INT NOT NULL DEFAULT 0,
    CreatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_user_contacts_account 
        FOREIGN KEY (AccountID) REFERENCES Accounts(AccountID) 
        ON DELETE CASCADE,
    CONSTRAINT chk_user_contacts_type 
        CHECK (ContactType IN ('Email', 'Phone', 'Telegram', 'WhatsApp', 'LinkedIn', 'GitHub', 'Other')),
    
    INDEX idx_user_contacts_account_id (AccountID),
    INDEX idx_user_contacts_type (ContactType, IsPublic)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- 4. Таблица SkillCategories (Категории навыков)
-- ============================================
CREATE TABLE SkillCategories (
    CategoryID BIGINT PRIMARY KEY AUTO_INCREMENT,
    Name VARCHAR(100) NOT NULL UNIQUE,
    Description TEXT NULL,
    IconURL VARCHAR(500) NULL,
    DisplayOrder INT NOT NULL DEFAULT 0,
    IsActive BOOLEAN NOT NULL DEFAULT TRUE,
    CreatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_skill_categories_active (IsActive, DisplayOrder)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- 5. Таблица SkillLevels (Уровни навыков)
-- ============================================
CREATE TABLE SkillLevels (
    LevelID BIGINT PRIMARY KEY AUTO_INCREMENT,
    Name VARCHAR(50) NOT NULL UNIQUE,
    Rank INT NOT NULL UNIQUE,
    Description TEXT NULL,
    CreatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_skill_levels_rank_sort (Rank)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- 6. Таблица SkillsCatalog (Каталог навыков)
-- ============================================
CREATE TABLE SkillsCatalog (
    SkillID BIGINT PRIMARY KEY AUTO_INCREMENT,
    SkillName VARCHAR(100) NOT NULL,
    CategoryID BIGINT NOT NULL,
    Description TEXT NULL,
    IsActive BOOLEAN NOT NULL DEFAULT TRUE,
    CreatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_skills_catalog_category 
        FOREIGN KEY (CategoryID) REFERENCES SkillCategories(CategoryID) 
        ON DELETE RESTRICT,
    
    UNIQUE INDEX idx_skills_catalog_name_category (SkillName, CategoryID),
    INDEX idx_skills_catalog_category_id (CategoryID),
    INDEX idx_skills_catalog_active (IsActive, SkillName)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- 7. Таблица UserSkills (Навыки пользователей)
-- ============================================
CREATE TABLE UserSkills (
    AccountID BIGINT NOT NULL,
    SkillID BIGINT NOT NULL,
    SkillLevelID BIGINT NOT NULL,
    IsVerified BOOLEAN NOT NULL DEFAULT FALSE,
    VerifiedAt DATETIME NULL,
    ExperienceYears DECIMAL(3,1) NULL,
    CreatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    PRIMARY KEY (AccountID, SkillID),
    CONSTRAINT fk_user_skills_account 
        FOREIGN KEY (AccountID) REFERENCES Accounts(AccountID) 
        ON DELETE CASCADE,
    CONSTRAINT fk_user_skills_skill 
        FOREIGN KEY (SkillID) REFERENCES SkillsCatalog(SkillID) 
        ON DELETE CASCADE,
    CONSTRAINT fk_user_skills_level 
        FOREIGN KEY (SkillLevelID) REFERENCES SkillLevels(LevelID) 
        ON DELETE RESTRICT,
    CONSTRAINT chk_user_skills_experience 
        CHECK (ExperienceYears IS NULL OR (ExperienceYears >= 0 AND ExperienceYears <= 100)),
    
    INDEX idx_user_skills_skill_id (SkillID),
    INDEX idx_user_skills_account_id (AccountID),
    INDEX idx_user_skills_verified (IsVerified, SkillID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- 8. Таблица Education (Образование)
-- ============================================
CREATE TABLE Education (
    EducationID BIGINT PRIMARY KEY AUTO_INCREMENT,
    AccountID BIGINT NOT NULL,
    InstitutionName VARCHAR(150) NOT NULL,
    DegreeField VARCHAR(100) NOT NULL,
    YearStarted INT NULL,
    YearCompleted INT NULL,
    DegreeLevel VARCHAR(50) NULL,
    IsCurrent BOOLEAN NOT NULL DEFAULT FALSE,
    CreatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_education_account 
        FOREIGN KEY (AccountID) REFERENCES Accounts(AccountID) 
        ON DELETE CASCADE,
    CONSTRAINT chk_education_year_started 
        CHECK (YearStarted IS NULL OR (YearStarted >= 1900 AND YearStarted <= 2100)),
    CONSTRAINT chk_education_year_completed 
        CHECK (YearCompleted IS NULL OR (YearCompleted >= 1900 AND YearCompleted <= 2100)),
    CONSTRAINT chk_education_years 
        CHECK (YearCompleted IS NULL OR YearStarted IS NULL OR YearCompleted >= YearStarted),
    CONSTRAINT chk_education_degree_level 
        CHECK (DegreeLevel IS NULL OR DegreeLevel IN ('Bachelor', 'Master', 'PhD', 'Certificate', 'Other')),
    
    INDEX idx_education_account_id (AccountID),
    INDEX idx_education_year_completed (YearCompleted)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- 9. Таблица Proofs (Документы)
-- ============================================
CREATE TABLE Proofs (
    ProofID BIGINT PRIMARY KEY AUTO_INCREMENT,
    AccountID BIGINT NOT NULL,
    SkillID BIGINT NULL,
    EducationID BIGINT NULL,
    FileURL VARCHAR(500) NOT NULL,
    FileName VARCHAR(255) NULL,
    FileSize BIGINT NULL,
    MimeType VARCHAR(100) NULL,
    Status VARCHAR(20) NOT NULL DEFAULT 'Pending',
    VerifiedBy BIGINT NULL,
    VerifiedAt DATETIME NULL,
    RejectionReason TEXT NULL,
    ExpiresAt DATETIME NULL,
    CreatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_proofs_account 
        FOREIGN KEY (AccountID) REFERENCES Accounts(AccountID) 
        ON DELETE CASCADE,
    CONSTRAINT fk_proofs_skill 
        FOREIGN KEY (SkillID) REFERENCES SkillsCatalog(SkillID) 
        ON DELETE SET NULL,
    CONSTRAINT fk_proofs_education 
        FOREIGN KEY (EducationID) REFERENCES Education(EducationID) 
        ON DELETE SET NULL,
    CONSTRAINT fk_proofs_verified_by 
        FOREIGN KEY (VerifiedBy) REFERENCES Accounts(AccountID) 
        ON DELETE SET NULL,
    CONSTRAINT chk_proofs_status 
        CHECK (Status IN ('Pending', 'Approved', 'Rejected', 'Expired')),
    CONSTRAINT chk_proofs_skill_or_education 
        CHECK (SkillID IS NOT NULL OR EducationID IS NOT NULL),
    
    INDEX idx_proofs_account_id (AccountID),
    INDEX idx_proofs_skill_id (SkillID),
    INDEX idx_proofs_status (Status, CreatedAt),
    INDEX idx_proofs_verified_by (VerifiedBy)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- 10. Таблица SkillPosts (Посты о навыках)
-- ============================================
CREATE TABLE SkillPosts (
    PostID BIGINT PRIMARY KEY AUTO_INCREMENT,
    AccountID BIGINT NOT NULL,
    SkillID BIGINT NOT NULL,
    PostType VARCHAR(20) NOT NULL,
    Title VARCHAR(100) NOT NULL,
    Details TEXT NOT NULL,
    Status VARCHAR(20) NOT NULL DEFAULT 'Active',
    ContactPreference VARCHAR(50) NULL,
    ExpiresAt DATETIME NULL,
    ViewsCount INT NOT NULL DEFAULT 0,
    CreatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    DeletedAt DATETIME NULL,
    
    CONSTRAINT fk_skill_posts_account 
        FOREIGN KEY (AccountID) REFERENCES Accounts(AccountID) 
        ON DELETE CASCADE,
    CONSTRAINT fk_skill_posts_skill 
        FOREIGN KEY (SkillID) REFERENCES SkillsCatalog(SkillID) 
        ON DELETE RESTRICT,
    CONSTRAINT chk_skill_posts_type 
        CHECK (PostType IN ('Offer', 'Request')),
    CONSTRAINT chk_skill_posts_status 
        CHECK (Status IN ('Active', 'Closed', 'Cancelled', 'Expired')),
    CONSTRAINT chk_skill_posts_details_length 
        CHECK (LENGTH(Details) <= 5000),
    
    INDEX idx_skill_posts_skill_status (SkillID, Status),
    INDEX idx_skill_posts_type (PostType, Status),
    INDEX idx_skill_posts_account_id (AccountID),
    INDEX idx_skill_posts_created_at (CreatedAt DESC),
    INDEX idx_skill_posts_deleted_at (DeletedAt)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- 11. Таблица VerificationRequests (Запросы на верификацию)
-- ============================================
CREATE TABLE VerificationRequests (
    RequestID BIGINT PRIMARY KEY AUTO_INCREMENT,
    AccountID BIGINT NOT NULL,
    ProofID BIGINT NOT NULL,
    RequestType VARCHAR(30) NOT NULL,
    Status VARCHAR(20) NOT NULL DEFAULT 'Pending',
    RequestMessage TEXT NULL,
    ReviewNotes TEXT NULL,
    CreatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ReviewedBy BIGINT NULL,
    ReviewedAt DATETIME NULL,
    UpdatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_verification_requests_account 
        FOREIGN KEY (AccountID) REFERENCES Accounts(AccountID) 
        ON DELETE CASCADE,
    CONSTRAINT fk_verification_requests_proof 
        FOREIGN KEY (ProofID) REFERENCES Proofs(ProofID) 
        ON DELETE CASCADE,
    CONSTRAINT fk_verification_requests_reviewed_by 
        FOREIGN KEY (ReviewedBy) REFERENCES Accounts(AccountID) 
        ON DELETE SET NULL,
    CONSTRAINT chk_verification_requests_type 
        CHECK (RequestType IN ('SkillVerification', 'EducationVerification', 'ProfileVerification')),
    CONSTRAINT chk_verification_requests_status 
        CHECK (Status IN ('Pending', 'InReview', 'Approved', 'Rejected', 'Cancelled')),
    
    INDEX idx_verification_requests_account_id (AccountID),
    INDEX idx_verification_requests_proof_id (ProofID),
    INDEX idx_verification_requests_status (Status, CreatedAt),
    INDEX idx_verification_requests_reviewed_by (ReviewedBy)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- 12. Таблица AuditLog (Журнал аудита)
-- ============================================
CREATE TABLE AuditLog (
    LogID BIGINT PRIMARY KEY AUTO_INCREMENT,
    ActorAccountID BIGINT NULL,
    Action VARCHAR(100) NOT NULL,
    EntityType VARCHAR(50) NOT NULL,
    EntityID BIGINT NULL,
    Details JSON NULL,
    IPAddress VARCHAR(45) NULL,
    UserAgent VARCHAR(500) NULL,
    Result VARCHAR(20) NULL,
    ErrorMessage TEXT NULL,
    CreatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_audit_log_actor 
        FOREIGN KEY (ActorAccountID) REFERENCES Accounts(AccountID) 
        ON DELETE SET NULL,
    CONSTRAINT chk_audit_log_result 
        CHECK (Result IS NULL OR Result IN ('Success', 'Failure', 'Error')),
    
    INDEX idx_audit_log_actor (ActorAccountID, CreatedAt DESC),
    INDEX idx_audit_log_entity (EntityType, EntityID),
    INDEX idx_audit_log_action (Action, CreatedAt DESC),
    INDEX idx_audit_log_created_at (CreatedAt DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- Заполнение справочных данных
-- ============================================

-- Добавление уровней навыков
INSERT INTO SkillLevels (Name, Rank, Description) VALUES
('Beginner', 1, 'Начальный уровень - базовые знания'),
('Intermediate', 2, 'Средний уровень - уверенное владение'),
('Advanced', 3, 'Продвинутый уровень - глубокие знания'),
('Expert', 4, 'Экспертный уровень - признанный специалист');

-- Добавление категорий навыков
INSERT INTO SkillCategories (Name, Description, DisplayOrder) VALUES
('Mathematics', 'Математические дисциплины', 1),
('Programming', 'Программирование и разработка', 2),
('Languages', 'Иностранные языки', 3),
('Science', 'Естественные науки', 4),
('Arts', 'Искусство и творчество', 5),
('Other', 'Прочее', 99);

-- Добавление навыков в каталог (примеры)
INSERT INTO SkillsCatalog (SkillName, CategoryID, Description) VALUES
('Linear Algebra', (SELECT CategoryID FROM SkillCategories WHERE Name = 'Mathematics'), 'Линейная алгебра'),
('Mathematical Analysis', (SELECT CategoryID FROM SkillCategories WHERE Name = 'Mathematics'), 'Математический анализ'),
('Python Programming', (SELECT CategoryID FROM SkillCategories WHERE Name = 'Programming'), 'Программирование на Python'),
('Java Programming', (SELECT CategoryID FROM SkillCategories WHERE Name = 'Programming'), 'Программирование на Java'),
('English Language', (SELECT CategoryID FROM SkillCategories WHERE Name = 'Languages'), 'Английский язык'),
('German Language', (SELECT CategoryID FROM SkillCategories WHERE Name = 'Languages'), 'Немецкий язык');


