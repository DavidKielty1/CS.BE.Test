namespace API.Services.Core.Utils;

public static class KeyBuilder
{
    public static string BuildKey(string name, int score, decimal salary)
    {
        return $"cards:{name}:{score}:{salary}".ToLower();
    }
}