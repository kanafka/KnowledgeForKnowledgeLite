using Npgsql;
using KnowledgeForKnowledgeLite.Models;
using BCrypt.Net;

namespace KnowledgeForKnowledgeLite.Services;

public class DatabaseService
{
    private readonly string _connectionString;

    // Helper methods для чтения данных из reader
    private static T GetValue<T>(NpgsqlDataReader reader, string columnName, T? defaultValue = default)
    {
        var value = reader[columnName];
        if (value == DBNull.Value)
            return defaultValue!;
        return (T)Convert.ChangeType(value, typeof(T));
    }
    
    private static T? GetNullableValue<T>(NpgsqlDataReader reader, string columnName) where T : struct
    {
        var value = reader[columnName];
        if (value == DBNull.Value)
            return null;
        return (T)Convert.ChangeType(value, typeof(T));
    }
    
    private static string? GetStringOrNull(NpgsqlDataReader reader, string columnName)
    {
        var value = reader[columnName];
        return value == DBNull.Value ? null : value.ToString();
    }

    public DatabaseService(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("DefaultConnection") 
            ?? throw new InvalidOperationException("Connection string 'DefaultConnection' not found.");
        
        // Логирование connection string (без пароля) для отладки
        var safeConnectionString = _connectionString;
        if (safeConnectionString.Contains("Password="))
        {
            var passwordIndex = safeConnectionString.IndexOf("Password=") + 9;
            var nextSemicolon = safeConnectionString.IndexOf(";", passwordIndex);
            if (nextSemicolon > passwordIndex)
            {
                safeConnectionString = safeConnectionString.Substring(0, passwordIndex) + "***" + safeConnectionString.Substring(nextSemicolon);
            }
        }
        Console.WriteLine($"[DatabaseService] Connection string configured: {safeConnectionString}");
    }

    public async Task<long> CreateAccountAsync(CreateAccountRequest request)
    {
        using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync();
        
            using var transaction = connection.BeginTransaction();
        
        try
        {
            // Вставка аккаунта
            var passwordHash = BCrypt.Net.BCrypt.HashPassword(request.Password);
            
            var insertAccountSql = @"
                INSERT INTO Accounts (Login, PasswordHash, EmailConfirmed, CreatedAt)
                VALUES (@Login, @PasswordHash, FALSE, NOW())
                RETURNING AccountID";
            
            using var accountCmd = new NpgsqlCommand(insertAccountSql, connection, transaction);
            accountCmd.Parameters.AddWithValue("@Login", request.Login);
            accountCmd.Parameters.AddWithValue("@PasswordHash", passwordHash);
            var accountId = Convert.ToInt64(await accountCmd.ExecuteScalarAsync() ?? throw new Exception("Failed to create account"));
            
            // Создание профиля
            var insertProfileSql = @"
                INSERT INTO UserProfiles (AccountID, IsActive, CreatedAt)
                VALUES (@AccountID, TRUE, NOW())";
            
            using var profileCmd = new NpgsqlCommand(insertProfileSql, connection, transaction);
            profileCmd.Parameters.AddWithValue("@AccountID", accountId);
            await profileCmd.ExecuteNonQueryAsync();
            
            // Логирование
            var insertLogSql = @"
                INSERT INTO AuditLog (ActorAccountID, Action, EntityType, EntityID, Result, CreatedAt)
                VALUES (@ActorAccountID, 'UserRegistered', 'Account', @EntityID, 'Success', NOW())";
            
            using var logCmd = new NpgsqlCommand(insertLogSql, connection, transaction);
            logCmd.Parameters.AddWithValue("@ActorAccountID", accountId);
            logCmd.Parameters.AddWithValue("@EntityID", accountId);
            await logCmd.ExecuteNonQueryAsync();
            
            transaction.Commit();
            return (long)accountId;
        }
        catch
        {
            transaction.Rollback();
            throw;
        }
    }

    public async Task<AccountDto?> GetAccountByLoginAsync(string login)
    {
        using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync();
        
        var sql = @"
            SELECT AccountID, Login, IsAdmin, EmailConfirmed, LastLoginAt, CreatedAt
            FROM Accounts
            WHERE Login = @Login AND DeletedAt IS NULL";
        
        using var cmd = new NpgsqlCommand(sql, connection);
        cmd.Parameters.AddWithValue("@Login", login);
        
        using var reader = await cmd.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            return new AccountDto(
                Convert.ToInt64(reader["AccountID"]),
                reader["Login"].ToString()!,
                Convert.ToBoolean(reader["IsAdmin"]),
                Convert.ToBoolean(reader["EmailConfirmed"]),
                reader["LastLoginAt"] == DBNull.Value ? null : Convert.ToDateTime(reader["LastLoginAt"]),
                Convert.ToDateTime(reader["CreatedAt"])
            );
        }
        
        return null;
    }

    public async Task<string?> GetPasswordHashAsync(string login)
    {
        using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync();
        
        var sql = "SELECT PasswordHash FROM Accounts WHERE Login = @Login AND DeletedAt IS NULL";
        
        using var cmd = new NpgsqlCommand(sql, connection);
        cmd.Parameters.AddWithValue("@Login", login);
        
        var result = await cmd.ExecuteScalarAsync();
        return result?.ToString();
    }

    public async Task UpdateLastLoginAsync(long accountId)
    {
        using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync();
        
        var sql = "UPDATE Accounts SET LastLoginAt = NOW() WHERE AccountID = @AccountID";
        
        using var cmd = new NpgsqlCommand(sql, connection);
        cmd.Parameters.AddWithValue("@AccountID", accountId);
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task SoftDeleteAccountAsync(long accountId)
    {
        using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync();
        
        using var transaction = connection.BeginTransaction();
        
        try
        {
            // Мягкое удаление аккаунта
            var updateAccountSql = "UPDATE Accounts SET DeletedAt = NOW(), UpdatedAt = NOW() WHERE AccountID = @AccountID";
            using var accountCmd = new NpgsqlCommand(updateAccountSql, connection, transaction);
            accountCmd.Parameters.AddWithValue("@AccountID", accountId);
            await accountCmd.ExecuteNonQueryAsync();
            
            // Деактивация профиля
            var updateProfileSql = "UPDATE UserProfiles SET IsActive = FALSE, UpdatedAt = NOW() WHERE AccountID = @AccountID";
            using var profileCmd = new NpgsqlCommand(updateProfileSql, connection, transaction);
            profileCmd.Parameters.AddWithValue("@AccountID", accountId);
            await profileCmd.ExecuteNonQueryAsync();
            
            // Закрытие всех активных постов
            var updatePostsSql = @"
                UPDATE SkillPosts 
                SET Status = 'Closed', DeletedAt = NOW(), UpdatedAt = NOW() 
                WHERE AccountID = @AccountID AND Status = 'Active' AND DeletedAt IS NULL";
            using var postsCmd = new NpgsqlCommand(updatePostsSql, connection, transaction);
            postsCmd.Parameters.AddWithValue("@AccountID", accountId);
            await postsCmd.ExecuteNonQueryAsync();
            
            // Логирование
            var insertLogSql = @"
                INSERT INTO AuditLog (ActorAccountID, Action, EntityType, EntityID, Result, CreatedAt)
                VALUES (@ActorAccountID, 'AccountDeleted', 'Account', @EntityID, 'Success', NOW())";
            using var logCmd = new NpgsqlCommand(insertLogSql, connection, transaction);
            logCmd.Parameters.AddWithValue("@ActorAccountID", accountId);
            logCmd.Parameters.AddWithValue("@EntityID", accountId);
            await logCmd.ExecuteNonQueryAsync();
            
            transaction.Commit();
        }
        catch
        {
            transaction.Rollback();
            throw;
        }
    }

    public async Task<UserProfileDto?> GetUserProfileAsync(long accountId)
    {
        using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync();
        
        var sql = @"
            SELECT AccountID, FullName, DateOfBirth, PhotoURL, Description, 
                   LastSeenOnline, IsActive, CreatedAt
            FROM UserProfiles
            WHERE AccountID = @AccountID";
        
        using var cmd = new NpgsqlCommand(sql, connection);
        cmd.Parameters.AddWithValue("@AccountID", accountId);
        
        using var reader = await cmd.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            return new UserProfileDto(
                Convert.ToInt64(reader["AccountID"]),
                reader["FullName"] == DBNull.Value ? null : reader["FullName"].ToString(),
                reader["DateOfBirth"] == DBNull.Value ? null : DateOnly.FromDateTime(Convert.ToDateTime(reader["DateOfBirth"])),
                reader["PhotoURL"] == DBNull.Value ? null : reader["PhotoURL"].ToString(),
                reader["Description"] == DBNull.Value ? null : reader["Description"].ToString(),
                reader["LastSeenOnline"] == DBNull.Value ? null : Convert.ToDateTime(reader["LastSeenOnline"]),
                Convert.ToBoolean(reader["IsActive"]),
                Convert.ToDateTime(reader["CreatedAt"])
            );
        }
        
        return null;
    }

    public async Task UpdateUserProfileAsync(long accountId, UpdateUserProfileRequest request)
    {
        using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync();
        
        var sql = @"
            UPDATE UserProfiles
            SET FullName = @FullName,
                DateOfBirth = @DateOfBirth,
                PhotoURL = @PhotoURL,
                Description = @Description,
                UpdatedAt = NOW()
            WHERE AccountID = @AccountID";
        
        using var cmd = new NpgsqlCommand(sql, connection);
        cmd.Parameters.AddWithValue("@AccountID", accountId);
        cmd.Parameters.AddWithValue("@FullName", (object?)request.FullName ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DateOfBirth", request.DateOfBirth.HasValue ? request.DateOfBirth.Value.ToDateTime(TimeOnly.MinValue) : DBNull.Value);
        cmd.Parameters.AddWithValue("@PhotoURL", (object?)request.PhotoURL ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Description", (object?)request.Description ?? DBNull.Value);
        
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task UpdateLastSeenOnlineAsync(long accountId)
    {
        using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync();
        
        var sql = "UPDATE UserProfiles SET LastSeenOnline = NOW() WHERE AccountID = @AccountID";
        
        using var cmd = new NpgsqlCommand(sql, connection);
        cmd.Parameters.AddWithValue("@AccountID", accountId);
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task<long> CreateUserContactAsync(long accountId, CreateUserContactRequest request)
    {
        using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync();
        
        var sql = @"
            INSERT INTO UserContacts (AccountID, ContactType, ContactValue, IsPublic, DisplayOrder, CreatedAt)
            VALUES (@AccountID, @ContactType, @ContactValue, @IsPublic, @DisplayOrder, NOW())
            RETURNING ContactID";
        
        using var cmd = new NpgsqlCommand(sql, connection);
        cmd.Parameters.AddWithValue("@AccountID", accountId);
        cmd.Parameters.AddWithValue("@ContactType", request.ContactType);
        cmd.Parameters.AddWithValue("@ContactValue", request.ContactValue);
        cmd.Parameters.AddWithValue("@IsPublic", request.IsPublic);
        cmd.Parameters.AddWithValue("@DisplayOrder", request.DisplayOrder);
        
        return Convert.ToInt64(await cmd.ExecuteScalarAsync() ?? throw new Exception("Failed to create contact"));
    }

    public async Task<List<UserContactDto>> GetUserContactsAsync(long accountId, bool publicOnly = false)
    {
        using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync();
        
        var sql = @"
            SELECT ContactID, AccountID, ContactType, ContactValue, IsPublic, DisplayOrder
            FROM UserContacts
            WHERE AccountID = @AccountID";
        
        if (publicOnly)
        {
            sql += " AND IsPublic = TRUE";
        }
        
        sql += " ORDER BY DisplayOrder";
        
        using var cmd = new NpgsqlCommand(sql, connection);
        cmd.Parameters.AddWithValue("@AccountID", accountId);
        
        var contacts = new List<UserContactDto>();
        using var reader = await cmd.ExecuteReaderAsync();
        
        while (await reader.ReadAsync())
        {
            contacts.Add(new UserContactDto(
                Convert.ToInt64(reader["ContactID"]),
                Convert.ToInt64(reader["AccountID"]),
                reader["ContactType"].ToString()!,
                reader["ContactValue"].ToString()!,
                Convert.ToBoolean(reader["IsPublic"]),
                Convert.ToInt32(reader["DisplayOrder"])
            ));
        }
        
        return contacts;
    }

    public async Task<List<SkillCategoryDto>> GetSkillCategoriesAsync()
    {
        using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync();
        
        var sql = @"
            SELECT CategoryID, Name, Description, IconURL, DisplayOrder, IsActive
            FROM SkillCategories
            WHERE IsActive = TRUE
            ORDER BY DisplayOrder";
        
        using var cmd = new NpgsqlCommand(sql, connection);
        var categories = new List<SkillCategoryDto>();
        
        using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            categories.Add(new SkillCategoryDto(
                Convert.ToInt64(reader["CategoryID"]),
                reader["Name"].ToString()!,
                reader["Description"] == DBNull.Value ? null : reader["Description"].ToString(),
                reader["IconURL"] == DBNull.Value ? null : reader["IconURL"].ToString(),
                Convert.ToInt32(reader["DisplayOrder"]),
                Convert.ToBoolean(reader["IsActive"])
            ));
        }
        
        return categories;
    }

    public async Task<List<SkillLevelDto>> GetSkillLevelsAsync()
    {
        using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync();
        
        var sql = @"
            SELECT LevelID, Name, Rank, Description
            FROM SkillLevels
            ORDER BY Rank";
        
        using var cmd = new NpgsqlCommand(sql, connection);
        var levels = new List<SkillLevelDto>();
        
        using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            levels.Add(new SkillLevelDto(
                Convert.ToInt64(reader["LevelID"]),
                reader["Name"].ToString()!,
                Convert.ToInt32(reader["Rank"]),
                reader["Description"] == DBNull.Value ? null : reader["Description"].ToString()
            ));
        }
        
        return levels;
    }

    public async Task<List<SkillCatalogDto>> GetSkillsByCategoryAsync(long? categoryId = null)
    {
        using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync();
        
        var sql = @"
            SELECT SkillID, SkillName, CategoryID, Description, IsActive
            FROM SkillsCatalog
            WHERE IsActive = TRUE";
        
        if (categoryId.HasValue)
        {
            sql += " AND CategoryID = @CategoryID";
        }
        
        sql += " ORDER BY SkillName";
        
        using var cmd = new NpgsqlCommand(sql, connection);
        if (categoryId.HasValue)
        {
            cmd.Parameters.AddWithValue("@CategoryID", categoryId.Value);
        }
        
        var skills = new List<SkillCatalogDto>();
        using var reader = await cmd.ExecuteReaderAsync();
        
        while (await reader.ReadAsync())
        {
            skills.Add(new SkillCatalogDto(
                Convert.ToInt64(reader["SkillID"]),
                reader["SkillName"].ToString()!,
                Convert.ToInt64(reader["CategoryID"]),
                reader["Description"] == DBNull.Value ? null : reader["Description"].ToString(),
                Convert.ToBoolean(reader["IsActive"])
            ));
        }
        
        return skills;
    }

    public async Task AddUserSkillAsync(long accountId, CreateUserSkillRequest request)
    {
        using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync();
        
        using var transaction = connection.BeginTransaction();
        
        try
        {
            // Добавление навыка
            var insertSkillSql = @"
                INSERT INTO UserSkills (AccountID, SkillID, SkillLevelID, IsVerified, ExperienceYears, CreatedAt)
                VALUES (@AccountID, @SkillID, @SkillLevelID, FALSE, @ExperienceYears, NOW())
                ON CONFLICT (AccountID, SkillID) 
                DO UPDATE SET
                    SkillLevelID = EXCLUDED.SkillLevelID,
                    ExperienceYears = EXCLUDED.ExperienceYears,
                    UpdatedAt = NOW()";
            
            using var skillCmd = new NpgsqlCommand(insertSkillSql, connection, transaction);
            skillCmd.Parameters.AddWithValue("@AccountID", accountId);
            skillCmd.Parameters.AddWithValue("@SkillID", request.SkillID);
            skillCmd.Parameters.AddWithValue("@SkillLevelID", request.SkillLevelID);
            skillCmd.Parameters.AddWithValue("@ExperienceYears", (object?)request.ExperienceYears ?? DBNull.Value);
            await skillCmd.ExecuteNonQueryAsync();
            
            // Логирование
            var insertLogSql = @"
                INSERT INTO AuditLog (ActorAccountID, Action, EntityType, EntityID, Details, Result, CreatedAt)
                VALUES (@ActorAccountID, 'SkillAdded', 'UserSkill', @EntityID, @Details::jsonb, 'Success', NOW())";
            
            using var logCmd = new NpgsqlCommand(insertLogSql, connection, transaction);
            logCmd.Parameters.AddWithValue("@ActorAccountID", accountId);
            logCmd.Parameters.AddWithValue("@EntityID", request.SkillID);
            
            var detailsJson = System.Text.Json.JsonSerializer.Serialize(new
            {
                SkillID = request.SkillID,
                SkillLevelID = request.SkillLevelID,
                ExperienceYears = request.ExperienceYears
            });
            logCmd.Parameters.AddWithValue("@Details", NpgsqlTypes.NpgsqlDbType.Jsonb, detailsJson);
            await logCmd.ExecuteNonQueryAsync();
            
            transaction.Commit();
        }
        catch
        {
            transaction.Rollback();
            throw;
        }
    }

    public async Task<List<UserSkillDto>> GetUserSkillsAsync(long accountId)
    {
        using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync();
        
        var sql = @"
            SELECT 
                us.AccountID,
                us.SkillID,
                sc.SkillName,
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
            WHERE us.AccountID = @AccountID
            ORDER BY cat.DisplayOrder, sc.SkillName";
        
        using var cmd = new NpgsqlCommand(sql, connection);
        cmd.Parameters.AddWithValue("@AccountID", accountId);
        
        var skills = new List<UserSkillDto>();
        using var reader = await cmd.ExecuteReaderAsync();
        
        while (await reader.ReadAsync())
        {
            skills.Add(new UserSkillDto(
                Convert.ToInt64(reader["AccountID"]),
                Convert.ToInt64(reader["SkillID"]),
                reader["SkillName"].ToString()!,
                reader["CategoryName"].ToString()!,
                reader["LevelName"].ToString()!,
                Convert.ToInt32(reader["LevelRank"]),
                Convert.ToBoolean(reader["IsVerified"]),
                reader["ExperienceYears"] == DBNull.Value ? null : Convert.ToDecimal(reader["ExperienceYears"]),
                Convert.ToDateTime(reader["AddedAt"])
            ));
        }
        
        return skills;
    }

    public async Task<List<UserProfileDto>> SearchUsersBySkillAsync(string skillName, int? minLevelRank = null)
    {
        using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync();
        
        var sql = @"
            SELECT DISTINCT
                a.AccountID,
                up.FullName,
                up.DateOfBirth,
                up.PhotoURL,
                up.Description,
                up.LastSeenOnline,
                up.IsActive,
                up.CreatedAt
            FROM Accounts a
            JOIN UserProfiles up ON a.AccountID = up.AccountID
            JOIN UserSkills us ON a.AccountID = us.AccountID
            JOIN SkillsCatalog sc ON us.SkillID = sc.SkillID
            JOIN SkillLevels sl ON us.SkillLevelID = sl.LevelID
            WHERE sc.SkillName = @SkillName
              AND a.DeletedAt IS NULL
              AND up.IsActive = TRUE";
        
        if (minLevelRank.HasValue)
        {
            sql += " AND sl.Rank >= @MinLevelRank";
        }
        
        sql += " ORDER BY sl.Rank DESC, up.LastSeenOnline DESC";
        
        using var cmd = new NpgsqlCommand(sql, connection);
        cmd.Parameters.AddWithValue("@SkillName", skillName);
        if (minLevelRank.HasValue)
        {
            cmd.Parameters.AddWithValue("@MinLevelRank", minLevelRank.Value);
        }
        
        var users = new List<UserProfileDto>();
        using var reader = await cmd.ExecuteReaderAsync();
        
        while (await reader.ReadAsync())
        {
            users.Add(new UserProfileDto(
                Convert.ToInt64(reader["AccountID"]),
                reader["FullName"] == DBNull.Value ? null : reader["FullName"].ToString(),
                reader["DateOfBirth"] == DBNull.Value ? null : DateOnly.FromDateTime(Convert.ToDateTime(reader["DateOfBirth"])),
                reader["PhotoURL"] == DBNull.Value ? null : reader["PhotoURL"].ToString(),
                reader["Description"] == DBNull.Value ? null : reader["Description"].ToString(),
                reader["LastSeenOnline"] == DBNull.Value ? null : Convert.ToDateTime(reader["LastSeenOnline"]),
                Convert.ToBoolean(reader["IsActive"]),
                Convert.ToDateTime(reader["CreatedAt"])
            ));
        }
        
        return users;
    }

    public async Task<long> CreateEducationAsync(long accountId, CreateEducationRequest request)
    {
        using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync();
        
        var sql = @"
            INSERT INTO Education (AccountID, InstitutionName, DegreeField, YearStarted, YearCompleted, DegreeLevel, IsCurrent, CreatedAt)
            VALUES (@AccountID, @InstitutionName, @DegreeField, @YearStarted, @YearCompleted, @DegreeLevel, @IsCurrent, NOW())
            RETURNING EducationID";
        
        using var cmd = new NpgsqlCommand(sql, connection);
        cmd.Parameters.AddWithValue("@AccountID", accountId);
        cmd.Parameters.AddWithValue("@InstitutionName", request.InstitutionName);
        cmd.Parameters.AddWithValue("@DegreeField", request.DegreeField);
        cmd.Parameters.AddWithValue("@YearStarted", (object?)request.YearStarted ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@YearCompleted", (object?)request.YearCompleted ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DegreeLevel", (object?)request.DegreeLevel ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@IsCurrent", request.IsCurrent);
        
        return Convert.ToInt64(await cmd.ExecuteScalarAsync() ?? throw new Exception("Failed to create education"));
    }

    public async Task<List<EducationDto>> GetUserEducationAsync(long accountId)
    {
        using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync();
        
        var sql = @"
            SELECT EducationID, AccountID, InstitutionName, DegreeField, YearStarted, YearCompleted, DegreeLevel, IsCurrent, CreatedAt
            FROM Education
            WHERE AccountID = @AccountID
            ORDER BY YearCompleted DESC, YearStarted DESC";
        
        using var cmd = new NpgsqlCommand(sql, connection);
        cmd.Parameters.AddWithValue("@AccountID", accountId);
        
        var educationList = new List<EducationDto>();
        using var reader = await cmd.ExecuteReaderAsync();
        
        while (await reader.ReadAsync())
        {
            educationList.Add(new EducationDto(
                Convert.ToInt64(reader["EducationID"]),
                Convert.ToInt64(reader["AccountID"]),
                reader["InstitutionName"].ToString()!,
                reader["DegreeField"].ToString()!,
                reader["YearStarted"] == DBNull.Value ? null : Convert.ToInt32(reader["YearStarted"]),
                reader["YearCompleted"] == DBNull.Value ? null : Convert.ToInt32(reader["YearCompleted"]),
                reader["DegreeLevel"] == DBNull.Value ? null : reader["DegreeLevel"].ToString(),
                Convert.ToBoolean(reader["IsCurrent"]),
                Convert.ToDateTime(reader["CreatedAt"])
            ));
        }
        
        return educationList;
    }

    public async Task<long> CreateProofAsync(long accountId, CreateProofRequest request)
    {
        using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync();
        
        using var transaction = connection.BeginTransaction();
        
        try
        {
            // Загрузка документа
            var insertProofSql = @"
                INSERT INTO Proofs (AccountID, SkillID, EducationID, FileURL, FileName, FileSize, MimeType, Status, CreatedAt)
                VALUES (@AccountID, @SkillID, @EducationID, @FileURL, @FileName, @FileSize, @MimeType, 'Pending', NOW())
                RETURNING ProofID";
            
            using var proofCmd = new NpgsqlCommand(insertProofSql, connection, transaction);
            proofCmd.Parameters.AddWithValue("@AccountID", accountId);
            proofCmd.Parameters.AddWithValue("@SkillID", (object?)request.SkillID ?? DBNull.Value);
            proofCmd.Parameters.AddWithValue("@EducationID", (object?)request.EducationID ?? DBNull.Value);
            proofCmd.Parameters.AddWithValue("@FileURL", request.FileURL);
            proofCmd.Parameters.AddWithValue("@FileName", (object?)request.FileName ?? DBNull.Value);
            proofCmd.Parameters.AddWithValue("@FileSize", (object?)request.FileSize ?? DBNull.Value);
            proofCmd.Parameters.AddWithValue("@MimeType", (object?)request.MimeType ?? DBNull.Value);
            var proofId = Convert.ToInt64(await proofCmd.ExecuteScalarAsync() ?? throw new Exception("Failed to create proof"));
            
            // Создание запроса на верификацию
            var insertRequestSql = @"
                INSERT INTO VerificationRequests (AccountID, ProofID, RequestType, Status, CreatedAt)
                VALUES (@AccountID, @ProofID, 
                    CASE WHEN @SkillID IS NOT NULL THEN 'SkillVerification' ELSE 'EducationVerification' END,
                    'Pending', NOW())";
            
            using var requestCmd = new NpgsqlCommand(insertRequestSql, connection, transaction);
            requestCmd.Parameters.AddWithValue("@AccountID", accountId);
            requestCmd.Parameters.AddWithValue("@ProofID", proofId);
            requestCmd.Parameters.AddWithValue("@SkillID", (object?)request.SkillID ?? DBNull.Value);
            await requestCmd.ExecuteNonQueryAsync();
            
            transaction.Commit();
            return (long)proofId;
        }
        catch
        {
            transaction.Rollback();
            throw;
        }
    }

    public async Task VerifyProofAsync(long proofId, long adminId, VerifyProofRequest request)
    {
        using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync();
        
        using var transaction = connection.BeginTransaction();
        
        try
        {
            // Обновление статуса документа
            var updateProofSql = @"
                UPDATE Proofs
                SET Status = @Status,
                    VerifiedBy = @AdminID,
                    VerifiedAt = NOW(),
                    RejectionReason = @RejectionReason,
                    UpdatedAt = NOW()
                WHERE ProofID = @ProofID";
            
            using var proofCmd = new NpgsqlCommand(updateProofSql, connection, transaction);
            proofCmd.Parameters.AddWithValue("@ProofID", proofId);
            proofCmd.Parameters.AddWithValue("@Status", request.Status);
            proofCmd.Parameters.AddWithValue("@AdminID", adminId);
            proofCmd.Parameters.AddWithValue("@RejectionReason", (object?)request.RejectionReason ?? DBNull.Value);
            await proofCmd.ExecuteNonQueryAsync();
            
            // Если одобрено, обновляем навык пользователя
            if (request.Status == "Approved")
            {
                var updateSkillSql = @"
                    UPDATE UserSkills
                    SET IsVerified = TRUE,
                        VerifiedAt = NOW(),
                        UpdatedAt = NOW()
                    WHERE AccountID = (SELECT AccountID FROM Proofs WHERE ProofID = @ProofID)
                      AND SkillID = (SELECT SkillID FROM Proofs WHERE ProofID = @ProofID)
                      AND SkillID IS NOT NULL";
                
                using var skillCmd = new NpgsqlCommand(updateSkillSql, connection, transaction);
                skillCmd.Parameters.AddWithValue("@ProofID", proofId);
                await skillCmd.ExecuteNonQueryAsync();
            }
            
            // Обновление запроса на верификацию
            var updateRequestSql = @"
                UPDATE VerificationRequests
                SET Status = @Status,
                    ReviewedBy = @AdminID,
                    ReviewedAt = NOW(),
                    ReviewNotes = @ReviewNotes,
                    UpdatedAt = NOW()
                WHERE ProofID = @ProofID AND Status = 'Pending'";
            
            using var requestCmd = new NpgsqlCommand(updateRequestSql, connection, transaction);
            requestCmd.Parameters.AddWithValue("@ProofID", proofId);
            requestCmd.Parameters.AddWithValue("@Status", request.Status);
            requestCmd.Parameters.AddWithValue("@AdminID", adminId);
            requestCmd.Parameters.AddWithValue("@ReviewNotes", (object?)request.ReviewNotes ?? DBNull.Value);
            await requestCmd.ExecuteNonQueryAsync();
            
            // Логирование
            var insertLogSql = @"
                INSERT INTO AuditLog (ActorAccountID, Action, EntityType, EntityID, Details, Result, CreatedAt)
                VALUES (@ActorAccountID, 'ProofVerified', 'Proof', @EntityID, @Details::jsonb, 'Success', NOW())";
            
            using var logCmd = new NpgsqlCommand(insertLogSql, connection, transaction);
            logCmd.Parameters.AddWithValue("@ActorAccountID", adminId);
            logCmd.Parameters.AddWithValue("@EntityID", proofId);
            
            var detailsJson = System.Text.Json.JsonSerializer.Serialize(new
            {
                ProofID = proofId,
                Decision = request.Status
            });
            logCmd.Parameters.AddWithValue("@Details", NpgsqlTypes.NpgsqlDbType.Jsonb, detailsJson);
            await logCmd.ExecuteNonQueryAsync();
            
            transaction.Commit();
        }
        catch
        {
            transaction.Rollback();
            throw;
        }
    }

    public async Task<List<ProofDto>> GetUserProofsAsync(long accountId)
    {
        using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync();
        
        var sql = @"
            SELECT ProofID, AccountID, SkillID, EducationID, FileURL, FileName, FileSize, MimeType,
                   Status, VerifiedBy, VerifiedAt, RejectionReason, ExpiresAt, CreatedAt
            FROM Proofs
            WHERE AccountID = @AccountID
            ORDER BY CreatedAt DESC";
        
        using var cmd = new NpgsqlCommand(sql, connection);
        cmd.Parameters.AddWithValue("@AccountID", accountId);
        
        var proofs = new List<ProofDto>();
        using var reader = await cmd.ExecuteReaderAsync();
        
        while (await reader.ReadAsync())
        {
            proofs.Add(new ProofDto(
                Convert.ToInt64(reader["ProofID"]),
                Convert.ToInt64(reader["AccountID"]),
                reader["SkillID"] == DBNull.Value ? null : Convert.ToInt64(reader["SkillID"]),
                reader["EducationID"] == DBNull.Value ? null : Convert.ToInt64(reader["EducationID"]),
                reader["FileURL"].ToString()!,
                reader["FileName"] == DBNull.Value ? null : reader["FileName"].ToString(),
                reader["FileSize"] == DBNull.Value ? null : Convert.ToInt64(reader["FileSize"]),
                reader["MimeType"] == DBNull.Value ? null : reader["MimeType"].ToString(),
                reader["Status"].ToString()!,
                reader["VerifiedBy"] == DBNull.Value ? null : Convert.ToInt64(reader["VerifiedBy"]),
                reader["VerifiedAt"] == DBNull.Value ? null : Convert.ToDateTime(reader["VerifiedAt"]),
                reader["RejectionReason"] == DBNull.Value ? null : reader["RejectionReason"].ToString(),
                reader["ExpiresAt"] == DBNull.Value ? null : Convert.ToDateTime(reader["ExpiresAt"]),
                Convert.ToDateTime(reader["CreatedAt"])
            ));
        }
        
        return proofs;
    }

    public async Task<long> CreateSkillPostAsync(long accountId, CreateSkillPostRequest request)
    {
        using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync();
        
        var sql = @"
            INSERT INTO SkillPosts (AccountID, SkillID, PostType, Title, Details, Status, ContactPreference, ExpiresAt, CreatedAt)
            VALUES (@AccountID, @SkillID, @PostType, @Title, @Details, 'Active', @ContactPreference, @ExpiresAt, NOW())
            RETURNING PostID";
        
        using var cmd = new NpgsqlCommand(sql, connection);
        cmd.Parameters.AddWithValue("@AccountID", accountId);
        cmd.Parameters.AddWithValue("@SkillID", request.SkillID);
        cmd.Parameters.AddWithValue("@PostType", request.PostType);
        cmd.Parameters.AddWithValue("@Title", request.Title);
        cmd.Parameters.AddWithValue("@Details", request.Details);
        cmd.Parameters.AddWithValue("@ContactPreference", (object?)request.ContactPreference ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ExpiresAt", (object?)request.ExpiresAt ?? DBNull.Value);
        
        return Convert.ToInt64(await cmd.ExecuteScalarAsync() ?? throw new Exception("Failed to create post"));
    }

    public async Task<List<SkillPostDto>> GetSkillPostsAsync(long? skillId = null, string? postType = null, string? status = "Active")
    {
        using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync();
        
        var sql = @"
            SELECT 
                sp.PostID,
                sp.AccountID,
                up.FullName AS AuthorName,
                sp.SkillID,
                sc.SkillName,
                sp.PostType,
                sp.Title,
                sp.Details,
                sp.Status,
                sp.ContactPreference,
                sp.ExpiresAt,
                sp.ViewsCount,
                sp.CreatedAt
            FROM SkillPosts sp
            JOIN Accounts a ON sp.AccountID = a.AccountID
            JOIN UserProfiles up ON a.AccountID = up.AccountID
            JOIN SkillsCatalog sc ON sp.SkillID = sc.SkillID
            WHERE sp.DeletedAt IS NULL";
        
        if (skillId.HasValue)
        {
            sql += " AND sp.SkillID = @SkillID";
        }
        
        if (!string.IsNullOrEmpty(postType))
        {
            sql += " AND sp.PostType = @PostType";
        }
        
        if (!string.IsNullOrEmpty(status))
        {
            sql += " AND sp.Status = @Status";
        }
        
        sql += " ORDER BY sp.CreatedAt DESC";
        
        using var cmd = new NpgsqlCommand(sql, connection);
        if (skillId.HasValue)
        {
            cmd.Parameters.AddWithValue("@SkillID", skillId.Value);
        }
        if (!string.IsNullOrEmpty(postType))
        {
            cmd.Parameters.AddWithValue("@PostType", postType);
        }
        if (!string.IsNullOrEmpty(status))
        {
            cmd.Parameters.AddWithValue("@Status", status);
        }
        
        var posts = new List<SkillPostDto>();
        using var reader = await cmd.ExecuteReaderAsync();
        
        while (await reader.ReadAsync())
        {
            posts.Add(new SkillPostDto(
                Convert.ToInt64(reader["PostID"]),
                Convert.ToInt64(reader["AccountID"]),
                reader["AuthorName"] == DBNull.Value ? "Unknown" : reader["AuthorName"].ToString()!,
                Convert.ToInt64(reader["SkillID"]),
                reader["SkillName"].ToString()!,
                reader["PostType"].ToString()!,
                reader["Title"].ToString()!,
                reader["Details"].ToString()!,
                reader["Status"].ToString()!,
                reader["ContactPreference"] == DBNull.Value ? null : reader["ContactPreference"].ToString(),
                reader["ExpiresAt"] == DBNull.Value ? null : Convert.ToDateTime(reader["ExpiresAt"]),
                Convert.ToInt32(reader["ViewsCount"]),
                Convert.ToDateTime(reader["CreatedAt"])
            ));
        }
        
        return posts;
    }

    public async Task IncrementPostViewsAsync(long postId)
    {
        using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync();
        
        using var transaction = connection.BeginTransaction();
        
        try
        {
            // Увеличение счетчика просмотров
            var updateViewsSql = @"
                UPDATE SkillPosts
                SET ViewsCount = ViewsCount + 1,
                    UpdatedAt = NOW()
                WHERE PostID = @PostID AND DeletedAt IS NULL";
            
            using var viewsCmd = new NpgsqlCommand(updateViewsSql, connection, transaction);
            viewsCmd.Parameters.AddWithValue("@PostID", postId);
            await viewsCmd.ExecuteNonQueryAsync();
            
            // Логирование просмотра
            var insertLogSql = @"
                INSERT INTO AuditLog (Action, EntityType, EntityID, Result, CreatedAt)
                VALUES ('PostViewed', 'SkillPost', @EntityID, 'Success', NOW())";
            
            using var logCmd = new NpgsqlCommand(insertLogSql, connection, transaction);
            logCmd.Parameters.AddWithValue("@EntityID", postId);
            await logCmd.ExecuteNonQueryAsync();
            
            transaction.Commit();
        }
        catch
        {
            transaction.Rollback();
            throw;
        }
    }

    public async Task UpdateSkillPostStatusAsync(long postId, string status)
    {
        using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync();
        
        var sql = "UPDATE SkillPosts SET Status = @Status, UpdatedAt = NOW() WHERE PostID = @PostID";
        
        using var cmd = new NpgsqlCommand(sql, connection);
        cmd.Parameters.AddWithValue("@PostID", postId);
        cmd.Parameters.AddWithValue("@Status", status);
        
        await cmd.ExecuteNonQueryAsync();
    }

}

