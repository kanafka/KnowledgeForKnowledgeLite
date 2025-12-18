namespace KnowledgeForKnowledgeLite.Models;

public record UserProfileDto(
    long AccountID,
    string? FullName,
    DateOnly? DateOfBirth,
    string? PhotoURL,
    string? Description,
    DateTime? LastSeenOnline,
    bool IsActive,
    DateTime CreatedAt
);

public record UpdateUserProfileRequest(
    string? FullName,
    DateOnly? DateOfBirth,
    string? PhotoURL,
    string? Description
);





