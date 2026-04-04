public class Brain.Mistral : Brain.OpenAiCompatible {
    public Mistral(string model_id, string api_key) {
        base("api.mistral.ai", "/v1/chat/completions", model_id, api_key);
    }
}
