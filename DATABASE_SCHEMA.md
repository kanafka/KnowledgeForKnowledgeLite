# Схема базы данных KnowledgeForKnowledgeLite

## Обзор

Система управления знаниями и навыками с функционалом верификации, публикации предложений/запросов и аудита действий пользователей.

---

## Таблицы

### 1. Accounts — Аккаунты и аутентификация

**Назначение:** Управление учетными записями, аутентификация, роли

| Поле | Тип | Ограничения | Описание |
|------|-----|-------------|----------|
| AccountID | UUID / BIGINT | PK, NOT NULL | Уникальный идентификатор аккаунта |
| Login | VARCHAR(100) | UNIQUE, NOT NULL | Уникальный логин (email / username) |
| PasswordHash | VARCHAR(255) | NOT NULL | Хэш пароля (BCrypt/Argon2) |
| IsAdmin | BOOLEAN | NOT NULL, DEFAULT FALSE | Флаг администратора |
| EmailConfirmed | BOOLEAN | NOT NULL, DEFAULT FALSE | Подтверждён ли email |
| LastLoginAt | DATETIME | NULL | Время последнего входа |
| PasswordUpdatedAt | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | Когда последний раз менялся пароль |
| CreatedAt | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | Дата регистрации |
| UpdatedAt | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | Время последнего обновления |
| DeletedAt | DATETIME | NULL | Мягкое удаление (soft delete) |

**Индексы:**
- `UNIQUE INDEX idx_accounts_login (Login)`
- `INDEX idx_accounts_deleted_at (DeletedAt)` — для фильтрации активных пользователей
- `INDEX idx_accounts_is_admin (IsAdmin)` — для быстрого поиска администраторов

**Внешние ключи:** Нет

**Замечания:**
- ✅ Добавлен `UpdatedAt` для отслеживания изменений
- ✅ Индексы для оптимизации запросов

---

### 2. UserProfiles — Профиль пользователя (1–1 с Accounts)

**Назначение:** Публичная и личная информация пользователя

| Поле | Тип | Ограничения | Описание |
|------|-----|-------------|----------|
| AccountID | UUID / BIGINT | PK, FK → Accounts(AccountID) ON DELETE CASCADE | Идентификатор аккаунта |
| FullName | VARCHAR(150) | NULL | Полное имя пользователя |
| DateOfBirth | DATE | NULL | Дата рождения |
| PhotoURL | VARCHAR(500) | NULL | URL фотографии профиля |
| Description | TEXT | NULL, CHECK (LENGTH(Description) <= 3000) | Описание (макс. 3000 символов) |
| LastSeenOnline | DATETIME | NULL | Последний раз онлайн |
| IsActive | BOOLEAN | NOT NULL, DEFAULT TRUE | Активен ли профиль |
| CreatedAt | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | Дата создания |
| UpdatedAt | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | Время обновления |

**Индексы:**
- `PRIMARY KEY (AccountID)`
- `INDEX idx_user_profiles_full_name (FullName)` — для поиска по имени
- `INDEX idx_user_profiles_is_active (IsActive)` — для фильтрации активных

**Внешние ключи:**
- `AccountID` → `Accounts(AccountID)` ON DELETE CASCADE

**Замечания:**
- ✅ Добавлен `UpdatedAt`
- ✅ Увеличен размер `PhotoURL` до 500 символов для длинных URL
- ✅ Добавлена проверка длины `Description`
- ✅ Явно указан FK с каскадным удалением

---

### 3. UserContacts — Контакты и приватность

**Назначение:** Гибкие настройки видимости контактной информации

| Поле | Тип | Ограничения | Описание |
|------|-----|-------------|----------|
| ContactID | UUID / BIGINT | PK, NOT NULL | Уникальный идентификатор контакта |
| AccountID | UUID / BIGINT | FK → Accounts(AccountID) ON DELETE CASCADE, NOT NULL | Идентификатор аккаунта |
| ContactType | VARCHAR(50) | NOT NULL | Тип контакта: 'Email', 'Phone', 'Telegram', 'WhatsApp', 'LinkedIn', 'GitHub', 'Other' |
| ContactValue | VARCHAR(255) | NOT NULL | Значение контакта |
| IsPublic | BOOLEAN | NOT NULL, DEFAULT FALSE | Публичная видимость |
| DisplayOrder | INT | NOT NULL, DEFAULT 0 | Порядок отображения |
| CreatedAt | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | Дата создания |
| UpdatedAt | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | Время обновления |

**Индексы:**
- `PRIMARY KEY (ContactID)`
- `INDEX idx_user_contacts_account_id (AccountID)`
- `INDEX idx_user_contacts_type (ContactType, IsPublic)` — для фильтрации по типу и видимости

**Внешние ключи:**
- `AccountID` → `Accounts(AccountID)` ON DELETE CASCADE

**Замечания:**
- ✅ `ContactType` заменён на VARCHAR с ограниченным набором значений (можно использовать CHECK или отдельную таблицу)
- ✅ Добавлен `DisplayOrder` для управления порядком отображения
- ✅ Добавлены `CreatedAt` и `UpdatedAt`
- ✅ Индекс для оптимизации запросов по типу и видимости

---

### 4. SkillCategories — Категории навыков

**Назначение:** Классификация навыков по категориям

| Поле | Тип | Ограничения | Описание |
|------|-----|-------------|----------|
| CategoryID | UUID / BIGINT | PK, NOT NULL | Уникальный идентификатор категории |
| Name | VARCHAR(100) | UNIQUE, NOT NULL | Название категории |
| Description | TEXT | NULL | Описание категории |
| IconURL | VARCHAR(500) | NULL | URL иконки категории |
| DisplayOrder | INT | NOT NULL, DEFAULT 0 | Порядок отображения |
| IsActive | BOOLEAN | NOT NULL, DEFAULT TRUE | Активна ли категория |
| CreatedAt | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | Дата создания |
| UpdatedAt | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | Время обновления |

**Индексы:**
- `PRIMARY KEY (CategoryID)`
- `UNIQUE INDEX idx_skill_categories_name (Name)`
- `INDEX idx_skill_categories_active (IsActive, DisplayOrder)` — для сортировки активных категорий

**Внешние ключи:** Нет

**Замечания:**
- ✅ Добавлены поля для улучшения UX: `Description`, `IconURL`, `DisplayOrder`
- ✅ Добавлен флаг `IsActive` для мягкого удаления категорий
- ✅ Добавлены `CreatedAt` и `UpdatedAt`

---

### 5. SkillsCatalog — Справочник навыков

**Назначение:** Централизованный каталог всех доступных навыков

| Поле | Тип | Ограничения | Описание |
|------|-----|-------------|----------|
| SkillID | UUID / BIGINT | PK, NOT NULL | Уникальный идентификатор навыка |
| SkillName | VARCHAR(100) | NOT NULL | Название навыка |
| CategoryID | UUID / BIGINT | FK → SkillCategories(CategoryID) ON DELETE RESTRICT, NOT NULL | Идентификатор категории |
| Description | TEXT | NULL | Описание навыка |
| IsActive | BOOLEAN | NOT NULL, DEFAULT TRUE | Активен ли навык |
| CreatedAt | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | Дата создания |
| UpdatedAt | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | Время обновления |

**Индексы:**
- `PRIMARY KEY (SkillID)`
- `UNIQUE INDEX idx_skills_catalog_name_category (SkillName, CategoryID)` — уникальность навыка в категории
- `INDEX idx_skills_catalog_category_id (CategoryID)`
- `INDEX idx_skills_catalog_active (IsActive, SkillName)` — для поиска активных навыков

**Внешние ключи:**
- `CategoryID` → `SkillCategories(CategoryID)` ON DELETE RESTRICT

**Замечания:**
- ✅ Добавлены `Description`, `IsActive`, `CreatedAt`, `UpdatedAt`
- ✅ RESTRICT на удаление категории защищает целостность данных
- ✅ Индексы для оптимизации поиска

---

### 6. SkillLevels — Уровни владения навыком

**Назначение:** Стандартизированные уровни компетенции

| Поле | Тип | Ограничения | Описание |
|------|-----|-------------|----------|
| LevelID | UUID / BIGINT | PK, NOT NULL | Уникальный идентификатор уровня |
| Name | VARCHAR(50) | UNIQUE, NOT NULL | Название уровня (например, "Beginner", "Intermediate", "Advanced", "Expert") |
| Rank | INT | UNIQUE, NOT NULL | Числовой ранг для сортировки (1, 2, 3, ...) |
| Description | TEXT | NULL | Описание уровня |
| CreatedAt | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | Дата создания |
| UpdatedAt | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | Время обновления |

**Индексы:**
- `PRIMARY KEY (LevelID)`
- `UNIQUE INDEX idx_skill_levels_name (Name)`
- `UNIQUE INDEX idx_skill_levels_rank (Rank)`
- `INDEX idx_skill_levels_rank_sort (Rank)` — для сортировки по рангу

**Внешние ключи:** Нет

**Замечания:**
- ✅ Добавлен `Description` для пояснения уровней
- ✅ `Rank` теперь UNIQUE для избежания дубликатов
- ✅ Добавлены `CreatedAt` и `UpdatedAt`

---

### 7. UserSkills — Навыки пользователя (M–M)

**Назначение:** Связь пользователей с навыками и уровнями владения

| Поле | Тип | Ограничения | Описание |
|------|-----|-------------|----------|
| AccountID | UUID / BIGINT | FK → Accounts(AccountID) ON DELETE CASCADE, NOT NULL | Идентификатор аккаунта |
| SkillID | UUID / BIGINT | FK → SkillsCatalog(SkillID) ON DELETE CASCADE, NOT NULL | Идентификатор навыка |
| SkillLevelID | UUID / BIGINT | FK → SkillLevels(LevelID) ON DELETE RESTRICT, NOT NULL | Идентификатор уровня |
| IsVerified | BOOLEAN | NOT NULL, DEFAULT FALSE | Верифицирован ли навык |
| VerifiedAt | DATETIME | NULL | Дата верификации |
| ExperienceYears | DECIMAL(3,1) | NULL, CHECK (ExperienceYears >= 0 AND ExperienceYears <= 100) | Опыт в годах |
| CreatedAt | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | Дата добавления |
| UpdatedAt | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | Время обновления |

**Индексы:**
- `PRIMARY KEY (AccountID, SkillID)`
- `INDEX idx_user_skills_skill_id (SkillID)` — для поиска всех пользователей с навыком
- `INDEX idx_user_skills_account_id (AccountID)` — для получения всех навыков пользователя
- `INDEX idx_user_skills_verified (IsVerified, SkillID)` — для поиска верифицированных навыков

**Внешние ключи:**
- `AccountID` → `Accounts(AccountID)` ON DELETE CASCADE
- `SkillID` → `SkillsCatalog(SkillID)` ON DELETE CASCADE
- `SkillLevelID` → `SkillLevels(LevelID)` ON DELETE RESTRICT

**Замечания:**
- ✅ Добавлено поле `ExperienceYears` для дополнительной информации
- ✅ Добавлено поле `VerifiedAt` для отслеживания времени верификации
- ✅ Добавлен `UpdatedAt`
- ✅ Каскадное удаление при удалении аккаунта или навыка
- ✅ RESTRICT на уровень для защиты целостности

---

### 8. Education — Образование

**Назначение:** Информация об образовании пользователя

| Поле | Тип | Ограничения | Описание |
|------|-----|-------------|----------|
| EducationID | UUID / BIGINT | PK, NOT NULL | Уникальный идентификатор записи |
| AccountID | UUID / BIGINT | FK → Accounts(AccountID) ON DELETE CASCADE, NOT NULL | Идентификатор аккаунта |
| InstitutionName | VARCHAR(150) | NOT NULL | Название учебного заведения |
| DegreeField | VARCHAR(100) | NOT NULL | Специальность / область |
| YearStarted | INT | NULL, CHECK (YearStarted >= 1900 AND YearStarted <= 2100) | Год начала обучения |
| YearCompleted | INT | NULL, CHECK (YearCompleted >= 1900 AND YearCompleted <= 2100) | Год окончания (NULL если не завершено) |
| DegreeLevel | VARCHAR(50) | NULL | Уровень: 'Bachelor', 'Master', 'PhD', 'Certificate', 'Other' |
| IsCurrent | BOOLEAN | NOT NULL, DEFAULT FALSE | Текущее образование |
| CreatedAt | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | Дата создания |
| UpdatedAt | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | Время обновления |

**Индексы:**
- `PRIMARY KEY (EducationID)`
- `INDEX idx_education_account_id (AccountID)`
- `INDEX idx_education_year_completed (YearCompleted)` — для поиска по году выпуска

**Внешние ключи:**
- `AccountID` → `Accounts(AccountID)` ON DELETE CASCADE

**Замечания:**
- ✅ Добавлены поля `YearStarted`, `DegreeLevel`, `IsCurrent` для полноты информации
- ✅ Добавлены проверки для годов
- ✅ Добавлены `CreatedAt` и `UpdatedAt`

---

### 9. Proofs — Подтверждающие документы

**Назначение:** Документы, подтверждающие навыки или образование

| Поле | Тип | Ограничения | Описание |
|------|-----|-------------|----------|
| ProofID | UUID / BIGINT | PK, NOT NULL | Уникальный идентификатор документа |
| AccountID | UUID / BIGINT | FK → Accounts(AccountID) ON DELETE CASCADE, NOT NULL | Идентификатор аккаунта |
| SkillID | UUID / BIGINT | FK → SkillsCatalog(SkillID) ON DELETE SET NULL, NULL | Связанный навык (NULL если для образования) |
| EducationID | UUID / BIGINT | FK → Education(EducationID) ON DELETE SET NULL, NULL | Связанное образование (NULL если для навыка) |
| FileURL | VARCHAR(500) | NOT NULL | URL файла документа |
| FileName | VARCHAR(255) | NULL | Оригинальное имя файла |
| FileSize | BIGINT | NULL | Размер файла в байтах |
| MimeType | VARCHAR(100) | NULL | MIME-тип файла |
| Status | VARCHAR(20) | NOT NULL, DEFAULT 'Pending' | Статус: 'Pending', 'Approved', 'Rejected', 'Expired' |
| VerifiedBy | UUID / BIGINT | FK → Accounts(AccountID) ON DELETE SET NULL, NULL | Кто верифицировал |
| VerifiedAt | DATETIME | NULL | Дата верификации |
| RejectionReason | TEXT | NULL | Причина отклонения (если Status = 'Rejected') |
| ExpiresAt | DATETIME | NULL | Срок действия (для временных документов) |
| CreatedAt | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | Дата создания |
| UpdatedAt | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | Время обновления |

**Индексы:**
- `PRIMARY KEY (ProofID)`
- `INDEX idx_proofs_account_id (AccountID)`
- `INDEX idx_proofs_skill_id (SkillID)`
- `INDEX idx_proofs_status (Status, CreatedAt)` — для поиска по статусу
- `INDEX idx_proofs_verified_by (VerifiedBy)` — для поиска документов, проверенных администратором

**Внешние ключи:**
- `AccountID` → `Accounts(AccountID)` ON DELETE CASCADE
- `SkillID` → `SkillsCatalog(SkillID)` ON DELETE SET NULL
- `EducationID` → `Education(EducationID)` ON DELETE SET NULL
- `VerifiedBy` → `Accounts(AccountID)` ON DELETE SET NULL

**Замечания:**
- ✅ Добавлена связь с `EducationID` для документов об образовании
- ✅ Добавлены поля для метаданных файла: `FileName`, `FileSize`, `MimeType`
- ✅ Добавлено поле `RejectionReason` для обратной связи
- ✅ Добавлено поле `ExpiresAt` для документов с ограниченным сроком действия
- ✅ `Status` заменён на VARCHAR с явными значениями
- ✅ SET NULL на `SkillID` при удалении навыка

---

### 10. SkillPosts — Предложения и запросы (объединены)

**Назначение:** Унифицированная таблица для предложений услуг и запросов на помощь

| Поле | Тип | Ограничения | Описание |
|------|-----|-------------|----------|
| PostID | UUID / BIGINT | PK, NOT NULL | Уникальный идентификатор поста |
| AccountID | UUID / BIGINT | FK → Accounts(AccountID) ON DELETE CASCADE, NOT NULL | Идентификатор автора |
| SkillID | UUID / BIGINT | FK → SkillsCatalog(SkillID) ON DELETE RESTRICT, NOT NULL | Идентификатор навыка |
| PostType | VARCHAR(20) | NOT NULL | Тип: 'Offer' (предложение), 'Request' (запрос) |
| Title | VARCHAR(100) | NOT NULL | Заголовок поста |
| Details | TEXT | NOT NULL, CHECK (LENGTH(Details) <= 5000) | Подробное описание (макс. 5000 символов) |
| Status | VARCHAR(20) | NOT NULL, DEFAULT 'Active' | Статус: 'Active', 'Closed', 'Cancelled', 'Expired' |
| ContactPreference | VARCHAR(50) | NULL | Предпочтительный способ связи |
| ExpiresAt | DATETIME | NULL | Срок действия поста |
| ViewsCount | INT | NOT NULL, DEFAULT 0 | Количество просмотров |
| CreatedAt | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | Дата создания |
| UpdatedAt | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | Время обновления |
| DeletedAt | DATETIME | NULL | Мягкое удаление |

**Индексы:**
- `PRIMARY KEY (PostID)`
- `INDEX idx_skill_posts_skill_status (SkillID, Status)` — для поиска активных постов по навыку
- `INDEX idx_skill_posts_type (PostType, Status)` — для фильтрации по типу
- `INDEX idx_skill_posts_account_id (AccountID)`
- `INDEX idx_skill_posts_created_at (CreatedAt DESC)` — для сортировки по дате
- `INDEX idx_skill_posts_deleted_at (DeletedAt)` — для фильтрации не удалённых

**Внешние ключи:**
- `AccountID` → `Accounts(AccountID)` ON DELETE CASCADE
- `SkillID` → `SkillsCatalog(SkillID)` ON DELETE RESTRICT

**Замечания:**
- ✅ Добавлены поля `ContactPreference`, `ExpiresAt`, `ViewsCount` для улучшения функциональности
- ✅ Добавлена проверка длины `Details`
- ✅ RESTRICT на удаление навыка защищает существующие посты
- ✅ Индексы оптимизированы для частых запросов

---

### 11. VerificationRequests — Журнал верификаций

**Назначение:** История запросов на верификацию (не дублирует Proofs)

| Поле | Тип | Ограничения | Описание |
|------|-----|-------------|----------|
| RequestID | UUID / BIGINT | PK, NOT NULL | Уникальный идентификатор запроса |
| AccountID | UUID / BIGINT | FK → Accounts(AccountID) ON DELETE CASCADE, NOT NULL | Идентификатор пользователя |
| ProofID | UUID / BIGINT | FK → Proofs(ProofID) ON DELETE CASCADE, NOT NULL | Связанный документ |
| RequestType | VARCHAR(30) | NOT NULL | Тип: 'SkillVerification', 'EducationVerification', 'ProfileVerification' |
| Status | VARCHAR(20) | NOT NULL, DEFAULT 'Pending' | Статус: 'Pending', 'InReview', 'Approved', 'Rejected', 'Cancelled' |
| RequestMessage | TEXT | NULL | Сообщение от пользователя |
| ReviewNotes | TEXT | NULL | Заметки проверяющего |
| CreatedAt | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | Дата создания |
| ReviewedBy | UUID / BIGINT | FK → Accounts(AccountID) ON DELETE SET NULL, NULL | Кто проверил |
| ReviewedAt | DATETIME | NULL | Дата проверки |
| UpdatedAt | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | Время обновления |

**Индексы:**
- `PRIMARY KEY (RequestID)`
- `INDEX idx_verification_requests_account_id (AccountID)`
- `INDEX idx_verification_requests_proof_id (ProofID)`
- `INDEX idx_verification_requests_status (Status, CreatedAt)` — для поиска по статусу
- `INDEX idx_verification_requests_reviewed_by (ReviewedBy)` — для поиска запросов администратора

**Внешние ключи:**
- `AccountID` → `Accounts(AccountID)` ON DELETE CASCADE
- `ProofID` → `Proofs(ProofID)` ON DELETE CASCADE
- `ReviewedBy` → `Accounts(AccountID)` ON DELETE SET NULL

**Замечания:**
- ✅ Добавлены поля `RequestMessage`, `ReviewNotes` для коммуникации
- ✅ Добавлен `UpdatedAt`
- ✅ Каскадное удаление при удалении пользователя или документа

---

### 12. AuditLog — Аудит действий

**Назначение:** Журнал всех значимых действий в системе

| Поле | Тип | Ограничения | Описание |
|------|-----|-------------|----------|
| LogID | UUID / BIGINT | PK, NOT NULL | Уникальный идентификатор записи |
| ActorAccountID | UUID / BIGINT | FK → Accounts(AccountID) ON DELETE SET NULL, NULL | Кто совершил действие (NULL для системных действий) |
| Action | VARCHAR(100) | NOT NULL | Тип действия (например, 'UserLogin', 'SkillAdded', 'ProofUploaded', 'PostCreated') |
| EntityType | VARCHAR(50) | NOT NULL | Тип сущности ('Account', 'Skill', 'Proof', 'Post', и т.д.) |
| EntityID | UUID / BIGINT | NULL | ID затронутой сущности |
| Details | JSON | NULL | Дополнительные детали действия в JSON |
| IPAddress | VARCHAR(45) | NULL | IP-адрес (поддержка IPv6) |
| UserAgent | VARCHAR(500) | NULL | User-Agent браузера |
| Result | VARCHAR(20) | NULL | Результат: 'Success', 'Failure', 'Error' |
| ErrorMessage | TEXT | NULL | Сообщение об ошибке (если Result = 'Error' или 'Failure') |
| CreatedAt | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | Время события |

**Индексы:**
- `PRIMARY KEY (LogID)`
- `INDEX idx_audit_log_actor (ActorAccountID, CreatedAt DESC)` — для истории действий пользователя
- `INDEX idx_audit_log_entity (EntityType, EntityID)` — для истории конкретной сущности
- `INDEX idx_audit_log_action (Action, CreatedAt DESC)` — для поиска по типу действия
- `INDEX idx_audit_log_created_at (CreatedAt DESC)` — для временных запросов

**Внешние ключи:**
- `ActorAccountID` → `Accounts(AccountID)` ON DELETE SET NULL

**Замечания:**
- ✅ Добавлены поля `Details` (JSON) для хранения произвольных данных
- ✅ Добавлены поля `IPAddress`, `UserAgent` для безопасности
- ✅ Добавлены поля `Result`, `ErrorMessage` для отслеживания ошибок
- ✅ Индексы оптимизированы для различных типов запросов

---

## Связи между таблицами

```
Accounts (1) ──< (1) UserProfiles
Accounts (1) ──< (*) UserContacts
Accounts (1) ──< (*) UserSkills
Accounts (1) ──< (*) Education
Accounts (1) ──< (*) Proofs
Accounts (1) ──< (*) SkillPosts
Accounts (1) ──< (*) VerificationRequests
Accounts (1) ──< (*) AuditLog (ActorAccountID)

SkillCategories (1) ──< (*) SkillsCatalog
SkillLevels (1) ──< (*) UserSkills
SkillsCatalog (1) ──< (*) UserSkills
SkillsCatalog (1) ──< (*) SkillPosts
SkillsCatalog (1) ──< (*) Proofs (nullable)

Education (1) ──< (*) Proofs (nullable)
Proofs (1) ──< (*) VerificationRequests
```

---

## Правила каскадного удаления

| Родительская таблица | Дочерняя таблица | Действие | Обоснование |
|---------------------|------------------|----------|-------------|
| Accounts | UserProfiles | CASCADE | Профиль не может существовать без аккаунта |
| Accounts | UserContacts | CASCADE | Контакты не могут существовать без аккаунта |
| Accounts | UserSkills | CASCADE | Навыки пользователя удаляются вместе с аккаунтом |
| Accounts | Education | CASCADE | Образование удаляется вместе с аккаунтом |
| Accounts | SkillPosts | CASCADE | Посты удаляются вместе с автором |
| Accounts | VerificationRequests | CASCADE | Запросы верификации удаляются вместе с пользователем |
| Accounts | Proofs | CASCADE | Документы удаляются вместе с пользователем |
| Accounts | AuditLog (ActorAccountID) | SET NULL | История аудита сохраняется, но актор обнуляется |
| SkillsCatalog | UserSkills | CASCADE | Навык удаляется из профилей пользователей |
| SkillsCatalog | SkillPosts | RESTRICT | Нельзя удалить навык, пока есть активные посты |
| SkillsCatalog | Proofs (SkillID) | SET NULL | Документ остаётся, но связь с навыком теряется |
| SkillCategories | SkillsCatalog | RESTRICT | Нельзя удалить категорию, пока есть навыки |
| SkillLevels | UserSkills | RESTRICT | Нельзя удалить уровень, пока есть пользователи с ним |
| Proofs | VerificationRequests | CASCADE | Запросы удаляются вместе с документом |

---

## Улучшения схемы

### Основные изменения:

1. **Добавлены поля `UpdatedAt`** во все таблицы для отслеживания времени последнего обновления
2. **Добавлены недостающие поля:**
   - `UserProfiles`: увеличен размер `PhotoURL`
   - `UserContacts`: `DisplayOrder` для сортировки
   - `SkillCategories`: `Description`, `IconURL`, `DisplayOrder`, `IsActive`
   - `SkillsCatalog`: `Description`, `IsActive`
   - `SkillLevels`: `Description`, `Rank` сделан UNIQUE
   - `UserSkills`: `ExperienceYears`, `VerifiedAt`
   - `Education`: `YearStarted`, `DegreeLevel`, `IsCurrent`
   - `Proofs`: `EducationID`, метаданные файла, `RejectionReason`, `ExpiresAt`
   - `SkillPosts`: `ContactPreference`, `ExpiresAt`, `ViewsCount`
   - `VerificationRequests`: `RequestMessage`, `ReviewNotes`
   - `AuditLog`: `Details`, `IPAddress`, `UserAgent`, `Result`, `ErrorMessage`

3. **Оптимизированы индексы:**
   - Добавлены индексы для часто используемых полей
   - Составные индексы для сложных запросов
   - Индексы для сортировки и фильтрации

4. **Улучшены ограничения:**
   - CHECK-ограничения для валидации данных (годы, длина текста, опыт)
   - UNIQUE-ограничения для предотвращения дубликатов
   - DEFAULT-значения для упрощения вставки

5. **Явно указаны внешние ключи** со всеми правилами ON DELETE

6. **ENUM заменены на VARCHAR** с явными значениями для гибкости и простоты миграций

7. **Добавлена поддержка мягкого удаления** где это уместно (`IsActive`, `DeletedAt`)

---

## Рекомендации по реализации

### 1. Индексы для производительности

Рекомендуется создать дополнительные индексы в зависимости от паттернов запросов:
- Полнотекстовый поиск по `UserProfiles.FullName`, `SkillsCatalog.SkillName`, `SkillPosts.Title`
- Составные индексы для частых комбинаций фильтров

### 2. Партиционирование

Рассмотрите партиционирование `AuditLog` по `CreatedAt` для больших объёмов данных.

### 3. Архивация

Реализуйте архивацию старых записей из `AuditLog` и удалённых постов из `SkillPosts`.

### 4. Валидация на уровне приложения

Добавьте валидацию:
- Email-формат для `Accounts.Login`
- Длины строк перед вставкой
- Логических проверок (например, `YearCompleted >= YearStarted`)

### 5. Триггеры

Рассмотрите создание триггеров:
- Автоматическое обновление `UserSkills.VerifiedAt` при изменении `IsVerified`
- Автоматическое создание записей в `AuditLog` при критических действиях

### 6. Резервное копирование

Учитывая важность данных, настройте регулярное резервное копирование, особенно для `Accounts`, `Proofs`, и `AuditLog`.

---

## Примеры типичных запросов

### Поиск пользователей по навыку
```sql
SELECT DISTINCT a.AccountID, up.FullName, us.SkillLevelID
FROM Accounts a
JOIN UserProfiles up ON a.AccountID = up.AccountID
JOIN UserSkills us ON a.AccountID = us.AccountID
JOIN SkillsCatalog sc ON us.SkillID = sc.SkillID
WHERE sc.SkillName = 'Python' 
  AND us.IsVerified = TRUE
  AND a.DeletedAt IS NULL;
```

### Получение активных постов по навыку
```sql
SELECT sp.*, a.Login, up.FullName, sc.SkillName
FROM SkillPosts sp
JOIN Accounts a ON sp.AccountID = a.AccountID
JOIN UserProfiles up ON a.AccountID = up.AccountID
JOIN SkillsCatalog sc ON sp.SkillID = sc.SkillID
WHERE sp.SkillID = ?
  AND sp.Status = 'Active'
  AND sp.DeletedAt IS NULL
ORDER BY sp.CreatedAt DESC;
```

---

## Версия схемы

**Версия:** 2.0  
**Дата обновления:** 2024  
**Автор:** KnowledgeForKnowledgeLite Team


