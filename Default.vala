namespace Brain {

	public BrainIa? create(string model_id, string api_key) {
		string m = model_id.down();

		if (("-" in m) == false) {
			return new OpenAi(model_id, api_key);
		}

		var prefix = m.split("-")[0];

		switch (prefix) {
			case "glm":
				return new Glm(model_id, api_key);
			case "gemini":
			case "gemma":
				return new Gemini(model_id, api_key);
			case "mistral":
			case "ministral":
			case "pixtral":
				return new Mistral(model_id, api_key);
			default:
			case "gpt":
			case "o1":
				return new OpenAi(model_id, api_key);
		}
	}


}
