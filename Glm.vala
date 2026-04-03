public class Glm : OpenAiCompatible {
    public Glm(string model_id, string api_key) {
        base("open.bigmodel.cn", "/api/paas/v4/chat/completions", model_id, api_key);
    }
}
