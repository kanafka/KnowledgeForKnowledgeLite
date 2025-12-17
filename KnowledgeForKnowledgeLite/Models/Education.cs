namespace KnowledgeForKnowledgeLite.Models;

public record EducationDto(
    long EducationID,
    long AccountID,
    string InstitutionName,
    string DegreeField,
    int? YearStarted,
    int? YearCompleted,
    string? DegreeLevel,
    bool IsCurrent,
    DateTime CreatedAt
);

public record CreateEducationRequest(
    string InstitutionName,
    string DegreeField,
    int? YearStarted,
    int? YearCompleted,
    string? DegreeLevel,
    bool IsCurrent
);


