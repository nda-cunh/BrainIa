public errordomain ResponseError {
	InvalidJson,
	ApiError,
	UnknownStructure
}

public abstract class Response {
	public string data_json;
	public string content;

	protected Response(string data_json) throws Error {
		this.data_json = data_json;
		this.content = parse_text_from_json(data_json);
	}

	protected abstract string parse_text_from_json(string raw_data) throws Error;
}
