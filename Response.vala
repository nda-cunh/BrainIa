public errordomain Brain.ResponseError {
	InvalidJson,
	ApiError,
	UnknownStructure
}

public abstract class Brain.Response {
	public string data_json;
	public string content;

	protected Response(string data_json) throws Error {
		this.data_json = data_json;
		this.content = parse_text_from_json(data_json);
	}

	protected abstract string parse_text_from_json(string raw_data) throws Error;

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
