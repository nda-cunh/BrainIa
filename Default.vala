namespace Brain {

	/**
	* The API family a model belongs to, picked from the model id.
	*/
	public enum Provider {
		OPENAI,
		ANTHROPIC,
		GEMINI,
		MISTRAL,
		GLM;

		/**
		* Short lowercase name of the provider ("openai", "anthropic", ...),
		* handy as a configuration key.
		*/
		public unowned string get_id() {
			switch (this) {
				case ANTHROPIC:
					return "anthropic";
				case GEMINI:
					return "gemini";
				case MISTRAL:
					return "mistral";
				case GLM:
					return "glm";
				default:
					return "openai";
			}
		}
	}

	/**
	* Tell which provider create() would use for a model, without building the client.
	* Useful to pick the right API key before calling create().
	* @param model_id The model id, e.g. "claude-sonnet-4-5" or "gpt-4o".
	* @return The provider of the model (OPENAI when the prefix is unknown).
	*/
	public Provider provider_of(string model_id) {
		string m = model_id.down();

		if (("-" in m) == false)
			return Provider.OPENAI;

		// keep the split in a variable: switching on a temporary array element
		// compares a string that has already been freed
		var parts = m.split("-");
		var prefix = parts[0];

		switch (prefix) {
			case "glm":
				return Provider.GLM;
			case "gemini":
			case "gemma":
				return Provider.GEMINI;
			case "mistral":
			case "ministral":
			case "pixtral":
			case "codestral":
				return Provider.MISTRAL;
			case "claude":
				return Provider.ANTHROPIC;
			default:
				return Provider.OPENAI;
		}
	}

	public BrainIa? create(string model_id, string api_key) {
		switch (provider_of(model_id)) {
			case Provider.GLM:
				return new Glm(model_id, api_key);
			case Provider.GEMINI:
				return new Gemini(model_id, api_key);
			case Provider.MISTRAL:
				return new Mistral(model_id, api_key);
			case Provider.ANTHROPIC:
				return new Anthropic(model_id, api_key);
			default:
				return new OpenAi(model_id, api_key);
		}
	}
}
