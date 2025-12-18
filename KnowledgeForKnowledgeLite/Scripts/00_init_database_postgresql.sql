CREATE DATABASE KnowledgeForKnowledgeLite;
DROP TABLE IF EXISTS AuditLog CASCADE;
DROP TABLE IF EXISTS VerificationRequests CASCADE;
DROP TABLE IF EXISTS SkillPosts CASCADE;
DROP TABLE IF EXISTS Proofs CASCADE;
DROP TABLE IF EXISTS Education CASCADE;
DROP TABLE IF EXISTS UserSkills CASCADE;
DROP TABLE IF EXISTS UserContacts CASCADE;
DROP TABLE IF EXISTS UserProfiles CASCADE;
DROP TABLE IF EXISTS SkillsCatalog CASCADE;
DROP TABLE IF EXISTS SkillLevels CASCADE;
DROP TABLE IF EXISTS SkillCategories CASCADE;
DROP TABLE IF EXISTS Accounts CASCADE;

-- ============================================
-- 1. Таблица Accounts (Аккаунты)
-- ============================================
CREATE TABLE Accounts (
    AccountID BIGSERIAL PRIMARY KEY,
    Login VARCHAR(100) NOT NULL UNIQUE,
    PasswordHash VARCHAR(255) NOT NULL,
    IsAdmin BOOLEAN NOT NULL DEFAULT FALSE,
    EmailConfirmed BOOLEAN NOT NULL DEFAULT FALSE,
    LastLoginAt TIMESTAMP NULL,
    PasswordUpdatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    DeletedAt TIMESTAMP NULL
);

CREATE INDEX idx_accounts_deleted_at ON Accounts(DeletedAt);
CREATE INDEX idx_accounts_is_admin ON Accounts(IsAdmin);

-- ============================================
-- 2. Таблица UserProfiles (Профили пользователей)
-- ============================================
CREATE TABLE UserProfiles (
    AccountID BIGINT PRIMARY KEY,
    FullName VARCHAR(150) NULL,
    DateOfBirth DATE NULL,
    PhotoURL VARCHAR(500) NULL,
    Description TEXT NULL,
    LastSeenOnline TIMESTAMP NULL,
    IsActive BOOLEAN NOT NULL DEFAULT TRUE,
    CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_user_profiles_description_length 
        CHECK (LENGTH(Description) <= 3000),
    CONSTRAINT fk_user_profiles_account 
        FOREIGN KEY (AccountID) REFERENCES Accounts(AccountID) 
        ON DELETE CASCADE
);

CREATE INDEX idx_user_profiles_full_name ON UserProfiles(FullName);
CREATE INDEX idx_user_profiles_is_active ON UserProfiles(IsActive);

-- ============================================
-- 3. Таблица UserContacts (Контакты)
-- ============================================
CREATE TABLE UserContacts (
    ContactID BIGSERIAL PRIMARY KEY,
    AccountID BIGINT NOT NULL,
    ContactType VARCHAR(50) NOT NULL,
    ContactValue VARCHAR(255) NOT NULL,
    IsPublic BOOLEAN NOT NULL DEFAULT FALSE,
    DisplayOrder INTEGER NOT NULL DEFAULT 0,
    CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_user_contacts_account 
        FOREIGN KEY (AccountID) REFERENCES Accounts(AccountID) 
        ON DELETE CASCADE,
    CONSTRAINT chk_user_contacts_type 
        CHECK (ContactType IN ('Email', 'Phone', 'Telegram', 'WhatsApp', 'LinkedIn', 'GitHub', 'Other'))
);

CREATE INDEX idx_user_contacts_account_id ON UserContacts(AccountID);
CREATE INDEX idx_user_contacts_type ON UserContacts(ContactType, IsPublic);

-- ============================================
-- 4. Таблица SkillCategories (Категории навыков)
-- ============================================
CREATE TABLE SkillCategories (
    CategoryID BIGSERIAL PRIMARY KEY,
    Name VARCHAR(100) NOT NULL UNIQUE,
    Description TEXT NULL,
    IconURL VARCHAR(500) NULL,
    DisplayOrder INTEGER NOT NULL DEFAULT 0,
    IsActive BOOLEAN NOT NULL DEFAULT TRUE,
    CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_skill_categories_active ON SkillCategories(IsActive, DisplayOrder);

-- ============================================
-- 5. Таблица SkillLevels (Уровни навыков)
-- ============================================
CREATE TABLE SkillLevels (
    LevelID BIGSERIAL PRIMARY KEY,
    Name VARCHAR(50) NOT NULL UNIQUE,
    Rank INTEGER NOT NULL UNIQUE,
    Description TEXT NULL,
    CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_skill_levels_rank_sort ON SkillLevels(Rank);

-- ============================================
-- 6. Таблица SkillsCatalog (Каталог навыков)
-- ============================================
CREATE TABLE SkillsCatalog (
    SkillID BIGSERIAL PRIMARY KEY,
    SkillName VARCHAR(100) NOT NULL,
    CategoryID BIGINT NOT NULL,
    Description TEXT NULL,
    IsActive BOOLEAN NOT NULL DEFAULT TRUE,
    CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_skills_catalog_category 
        FOREIGN KEY (CategoryID) REFERENCES SkillCategories(CategoryID) 
        ON DELETE RESTRICT,
    
    CONSTRAINT uq_skills_catalog_name_category UNIQUE (SkillName, CategoryID)
);

CREATE INDEX idx_skills_catalog_category_id ON SkillsCatalog(CategoryID);
CREATE INDEX idx_skills_catalog_active ON SkillsCatalog(IsActive, SkillName);

-- ============================================
-- 7. Таблица UserSkills (Навыки пользователей)
-- ============================================
CREATE TABLE UserSkills (
    AccountID BIGINT NOT NULL,
    SkillID BIGINT NOT NULL,
    SkillLevelID BIGINT NOT NULL,
    IsVerified BOOLEAN NOT NULL DEFAULT FALSE,
    VerifiedAt TIMESTAMP NULL,
    ExperienceYears DECIMAL(3,1) NULL,
    CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
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
        CHECK (ExperienceYears IS NULL OR (ExperienceYears >= 0 AND ExperienceYears <= 100))
);

CREATE INDEX idx_user_skills_skill_id ON UserSkills(SkillID);
CREATE INDEX idx_user_skills_account_id ON UserSkills(AccountID);
CREATE INDEX idx_user_skills_verified ON UserSkills(IsVerified, SkillID);

-- ============================================
-- 8. Таблица Education (Образование)
-- ============================================
CREATE TABLE Education (
    EducationID BIGSERIAL PRIMARY KEY,
    AccountID BIGINT NOT NULL,
    InstitutionName VARCHAR(150) NOT NULL,
    DegreeField VARCHAR(100) NOT NULL,
    YearStarted INTEGER NULL,
    YearCompleted INTEGER NULL,
    DegreeLevel VARCHAR(50) NULL,
    IsCurrent BOOLEAN NOT NULL DEFAULT FALSE,
    CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
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
        CHECK (DegreeLevel IS NULL OR DegreeLevel IN ('Bachelor', 'Master', 'PhD', 'Certificate', 'Other'))
);

CREATE INDEX idx_education_account_id ON Education(AccountID);
CREATE INDEX idx_education_year_completed ON Education(YearCompleted);

-- ============================================
-- 9. Таблица Proofs (Документы)
-- ============================================
CREATE TABLE Proofs (
    ProofID BIGSERIAL PRIMARY KEY,
    AccountID BIGINT NOT NULL,
    SkillID BIGINT NULL,
    EducationID BIGINT NULL,
    FileURL VARCHAR(500) NOT NULL,
    FileName VARCHAR(255) NULL,
    FileSize BIGINT NULL,
    MimeType VARCHAR(100) NULL,
    Status VARCHAR(20) NOT NULL DEFAULT 'Pending',
    VerifiedBy BIGINT NULL,
    VerifiedAt TIMESTAMP NULL,
    RejectionReason TEXT NULL,
    ExpiresAt TIMESTAMP NULL,
    CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
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
        CHECK (SkillID IS NOT NULL OR EducationID IS NOT NULL)
);

CREATE INDEX idx_proofs_account_id ON Proofs(AccountID);
CREATE INDEX idx_proofs_skill_id ON Proofs(SkillID);
CREATE INDEX idx_proofs_status ON Proofs(Status, CreatedAt);
CREATE INDEX idx_proofs_verified_by ON Proofs(VerifiedBy);

-- ============================================
-- 10. Таблица SkillPosts (Посты о навыках)
-- ============================================
CREATE TABLE SkillPosts (
    PostID BIGSERIAL PRIMARY KEY,
    AccountID BIGINT NOT NULL,
    SkillID BIGINT NOT NULL,
    PostType VARCHAR(20) NOT NULL,
    Title VARCHAR(100) NOT NULL,
    Details TEXT NOT NULL,
    Status VARCHAR(20) NOT NULL DEFAULT 'Active',
    ContactPreference VARCHAR(50) NULL,
    ExpiresAt TIMESTAMP NULL,
    ViewsCount INTEGER NOT NULL DEFAULT 0,
    CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    DeletedAt TIMESTAMP NULL,
    
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
        CHECK (LENGTH(Details) <= 5000)
);

CREATE INDEX idx_skill_posts_skill_status ON SkillPosts(SkillID, Status);
CREATE INDEX idx_skill_posts_type ON SkillPosts(PostType, Status);
CREATE INDEX idx_skill_posts_account_id ON SkillPosts(AccountID);
CREATE INDEX idx_skill_posts_created_at ON SkillPosts(CreatedAt DESC);
CREATE INDEX idx_skill_posts_deleted_at ON SkillPosts(DeletedAt);

-- ============================================
-- 11. Таблица VerificationRequests (Запросы на верификацию)
-- ============================================
CREATE TABLE VerificationRequests (
    RequestID BIGSERIAL PRIMARY KEY,
    AccountID BIGINT NOT NULL,
    ProofID BIGINT NOT NULL,
    RequestType VARCHAR(30) NOT NULL,
    Status VARCHAR(20) NOT NULL DEFAULT 'Pending',
    RequestMessage TEXT NULL,
    ReviewNotes TEXT NULL,
    CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ReviewedBy BIGINT NULL,
    ReviewedAt TIMESTAMP NULL,
    UpdatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
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
        CHECK (Status IN ('Pending', 'InReview', 'Approved', 'Rejected', 'Cancelled'))
);

CREATE INDEX idx_verification_requests_account_id ON VerificationRequests(AccountID);
CREATE INDEX idx_verification_requests_proof_id ON VerificationRequests(ProofID);
CREATE INDEX idx_verification_requests_status ON VerificationRequests(Status, CreatedAt);
CREATE INDEX idx_verification_requests_reviewed_by ON VerificationRequests(ReviewedBy);

-- ============================================
-- 12. Таблица AuditLog (Журнал аудита)
-- ============================================
CREATE TABLE AuditLog (
    LogID BIGSERIAL PRIMARY KEY,
    ActorAccountID BIGINT NULL,
    Action VARCHAR(100) NOT NULL,
    EntityType VARCHAR(50) NOT NULL,
    EntityID BIGINT NULL,
    Details JSONB NULL,
    IPAddress VARCHAR(45) NULL,
    UserAgent VARCHAR(500) NULL,
    Result VARCHAR(20) NULL,
    ErrorMessage TEXT NULL,
    CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_audit_log_actor 
        FOREIGN KEY (ActorAccountID) REFERENCES Accounts(AccountID) 
        ON DELETE SET NULL,
    CONSTRAINT chk_audit_log_result 
        CHECK (Result IS NULL OR Result IN ('Success', 'Failure', 'Error'))
);

CREATE INDEX idx_audit_log_actor ON AuditLog(ActorAccountID, CreatedAt DESC);
CREATE INDEX idx_audit_log_entity ON AuditLog(EntityType, EntityID);
CREATE INDEX idx_audit_log_action ON AuditLog(Action, CreatedAt DESC);
CREATE INDEX idx_audit_log_created_at ON AuditLog(CreatedAt DESC);

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


