namespace KnowledgeForKnowledgeLite.Models;

public record SkillCategoryDto(
    long CategoryID,
    string Name,
    string? Description,
    string? IconURL,
    int DisplayOrder,
    bool IsActive
);

public record SkillLevelDto(
    long LevelID,
    string Name,
    int Rank,
    string? Description
);

public record SkillCatalogDto(
    long SkillID,
    string SkillName,
    long CategoryID,
    string? Description,
    bool IsActive
);

public record UserSkillDto(
    long AccountID,
    long SkillID,
    string SkillName,
    string CategoryName,
    string LevelName,
    int LevelRank,
    bool IsVerified,
    decimal? ExperienceYears,
    DateTime CreatedAt
);

public record CreateUserSkillRequest(
    long SkillID,
    long SkillLevelID,
    decimal? ExperienceYears
);





