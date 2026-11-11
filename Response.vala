public errordomain Brain.ResponseError {
	InvalidJson,
	ApiError,
	UnknownStructure
}

public abstract class Brain.Response {
	public string data_json;
	public string content;
	/** Tokens of the prompt, including cached_tokens (0 when the API does not say). */
	public int input_tokens;
	/** Tokens generated, including reasoning_tokens. */
	public int output_tokens;
	/** Part of input_tokens read from the provider's prompt cache. */
	public int cached_tokens;
	/** Part of output_tokens spent thinking (reasoning models). */
	public int reasoning_tokens;
	/** Part of input_tokens written to the prompt cache (Anthropic, and OpenAI models that bill it). */
	public int cache_write_tokens;

	protected Response(string data_json) throws Error {
		this.data_json = data_json;
		this.content = parse_text_from_json(data_json);
	}

	protected abstract string parse_text_from_json(string raw_data) throws Error;

	/**
	* Fill the token counts from the usage block of the response, whatever the provider:
	* "usage" with prompt_tokens (OpenAI, Mistral, Glm and other compatible APIs),
	* "usage" with input_tokens (Anthropic, which counts cached tokens apart) or
	* "usageMetadata" (Gemini). Missing fields stay at 0.
	* @param root The root object of the parsed response.
	*/
	internal void read_usage (YYJson.Value root) {
		unowned var usage = root.obj_get("usage");
		if (usage != null && usage.obj_get("prompt_tokens") != null) {
			input_tokens = int_of(usage, "prompt_tokens");
			output_tokens = int_of(usage, "completion_tokens");
			unowned var pdetails = usage.obj_get("prompt_tokens_details");
			if (pdetails != null) {
				cached_tokens = int_of(pdetails, "cached_tokens");
				cache_write_tokens = int_of(pdetails, "cache_write_tokens");
			}
			unowned var cdetails = usage.obj_get("completion_tokens_details");
			if (cdetails != null)
				reasoning_tokens = int_of(cdetails, "reasoning_tokens");
			return;
		}
		if (usage != null && usage.obj_get("input_tokens") != null) {
			cached_tokens = int_of(usage, "cache_read_input_tokens");
			cache_write_tokens = int_of(usage, "cache_creation_input_tokens");
			input_tokens = int_of(usage, "input_tokens") + cached_tokens + cache_write_tokens;
			output_tokens = int_of(usage, "output_tokens");
			return;
		}
		unowned var meta = root.obj_get("usageMetadata");
		if (meta != null) {
			input_tokens = int_of(meta, "promptTokenCount");
			cached_tokens = int_of(meta, "cachedContentTokenCount");
			reasoning_tokens = int_of(meta, "thoughtsTokenCount");
			output_tokens = int_of(meta, "candidatesTokenCount") + reasoning_tokens;
		}
	}

	private static int int_of (YYJson.Value obj, string key) {
		unowned var v = obj.obj_get(key);
		return v != null ? v.get_int() : 0;
	}

	/**
	* Raise the error reported by the API, whatever shape it uses.
	* OpenAI, Gemini and Anthropic nest it under "error", Mistral answers
	* flat with {"object": "error", "message": "..."} and some gateways
	* only send {"detail": "..."}.
	* @param root The root object of the parsed response.
	* @throws Error If the response carries an API error.
	*/
	internal void check_api_error (YYJson.Value root) throws Error {
		unowned var error_val = root.obj_get("error");
		if (error_val != null) {
			unowned string? as_str = error_val.get_str();
			if (as_str != null)
				throw new ResponseError.ApiError("API error: %s", as_str);

			unowned var msg = error_val.obj_get("message");
			unowned var code_val = error_val.obj_get("code");
			int code = code_val != null ? code_val.get_int() : 0;

			if (code != 0)
				throw new ResponseError.ApiError("API error %d: %s", code, msg != null ? msg.get_str() : "unknown");
			throw new ResponseError.ApiError("API error: %s", msg != null ? msg.get_str() : "unknown");
		}

		unowned var object_val = root.obj_get("object");
		unowned var flat_msg = root.obj_get("message");
		if (object_val != null && object_val.get_str() == "error" && flat_msg != null)
			throw new ResponseError.ApiError("API error: %s", flat_msg.get_str());

		unowned var detail = root.obj_get("detail");
		if (detail != null && detail.get_str() != null)
			throw new ResponseError.ApiError("API error: %s", detail.get_str());
	}
}
