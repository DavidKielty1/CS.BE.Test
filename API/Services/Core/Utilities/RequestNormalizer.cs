namespace API.Services.Core.Utilities;

public static class RequestNormalizer
{
    public static int NormalizeScore(int score) =>
        Math.Min(Math.Max(0, score), 700);

    public static int NormalizeSalary(int salary) =>
        Math.Max(0, salary);

    public static string BuildRedisKey(string name, int score, int salary) =>
        $"creditcard:request:{Uri.EscapeDataString(name)}:{score}:{salary}";
}