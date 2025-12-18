namespace KnowledgeForKnowledgeLite.Models;

public record SkillPostDto(
    long PostID,
    long AccountID,
    string AuthorName,
    long SkillID,
    string SkillName,
    string PostType,
    string Title,
    string Details,
    string Status,
    string? ContactPreference,
    DateTime? ExpiresAt,
    int ViewsCount,
    DateTime CreatedAt
);

public record CreateSkillPostRequest(
    long SkillID,
    string PostType,
    string Title,
    string Details,
    string? ContactPreference,
    DateTime? ExpiresAt
);

public record UpdateSkillPostStatusRequest(
    string Status
);




