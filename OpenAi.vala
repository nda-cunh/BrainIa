public class Brain.OpenAi : Brain.OpenAiCompatible {
	public OpenAi(string model_id, string api_key) {
		base("api.openai.com", "/v1/chat/completions", model_id, api_key);
	}
}
