public class Brain.Mistral : Brain.OpenAiCompatible {
    private const string PREFIX = "mistral-";
    private const string[] FORWARDED = { "glm", "deepseek", "zai" };

    public Mistral (string model_id, string api_key) {
        base ("api.mistral.ai", "/v1/chat/completions", model_id, api_key);
    }

    public static string get_real_name (string model_id) {
        if (!model_id.has_prefix (PREFIX)) {
            return model_id;
        }
        string rest = model_id.substring (PREFIX.length);
        foreach (unowned string p in FORWARDED) {
            if (rest.has_prefix (p)) {
                return rest;
            }
        }
        return model_id;
    }
}
