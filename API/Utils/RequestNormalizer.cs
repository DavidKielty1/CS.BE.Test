namespace API.Utils
{
    public static class RequestNormalizer
    {
        public static int NormalizeScore(int score) => Math.Max(0, Math.Min(score, 700
        ));

        public static int NormalizeSalary(int salary) => Math.Max(0, salary);

        public static string BuildRedisKey(string name, int score, int salary)
            => $"cards:{name}:{score}:{salary}";
    }
}