using Json;

public class GeminiResponse: Response {
	public GeminiResponse(string data_json) throws Error {
		base(data_json);
	}

	public override string parse_text_from_json(string raw_data) throws Error {
		int start = raw_data.index_of("{");
		int end = raw_data.last_index_of("}");

		if (start == -1 || end == -1 || end < start) {
			throw new ResponseError.InvalidJson("Invalid JSON format: %s", raw_data);
		}

		string clean_json = raw_data.substring(start, end - start + 1);

		var parser = new Json.Parser();
		parser.load_from_data(clean_json, -1);
		var root = parser.get_root().get_object();

		// If the API returned an error, extract and return the error message
		if (root.has_member("error")) {
			var error_node = root.get_object_member("error");
			string message = error_node.get_string_member("message");
			int code = (int)error_node.get_int_member("code");
			throw new ResponseError.ApiError("API Error %d: %s", code, message);
		}

		// If the content is present, extract and return it
		if (root.has_member("candidates")) {
			var candidates = root.get_array_member("candidates");
			if (candidates.get_length() > 0) {
				var first_candidate = candidates.get_object_element(0);
				if (first_candidate.has_member("content")) {
					var content_node = first_candidate.get_object_member("content");
					var parts = content_node.get_array_member("parts");
					if (parts.get_length() > 0) {
						return parts.get_object_element(0).get_string_member("text");
					}
				}
			}
		}

		throw new ResponseError.UnknownStructure("Unrecognized JSON structure %s", clean_json);
	}
}


public class Gemini: BrainIa {

    public Gemini(string model_id, string api_key) {
        this.model_id = model_id;
        this.api_key = api_key;
    }

    public override Response? send(string prompt) throws Error {
        var client = new SocketClient() { tls = true };
        var conn = client.connect_to_host("generativelanguage.googleapis.com", 443);

		var builder = new Json.Builder();
			builder.begin_object();
				builder.set_member_name("contents");
				builder.begin_array();
					builder.begin_object();
						builder.set_member_name("parts");
						builder.begin_array();
							builder.begin_object();
								builder.set_member_name("text");
								builder.add_string_value(prompt);
							builder.end_object();
						builder.end_array();
					builder.end_object();
				builder.end_array();
			builder.end_object();

		var generator = new Json.Generator();
		generator.set_root(builder.get_root());
		string payload = generator.to_data(null);

        StringBuilder sb = new StringBuilder();
        sb.append (@"POST /v1beta/models/$(this.model_id):generateContent HTTP/1.1\r\n");
        sb.append ("Host: generativelanguage.googleapis.com\r\n");
		sb.append ("Content-Type: application/json; charset=utf-8\r\n");
		sb.append (@"x-goog-api-key: $(this.api_key)\r\n");
        sb.append ("Content-Length: %d\r\n".printf(payload.length));
        sb.append ("Connection: close\r\n");
        sb.append ("\r\n");
        sb.append (payload);

        conn.output_stream.write_all(sb.str.data, null);
        conn.output_stream.flush();

        var input = new DataInputStream(conn.input_stream);
        StringBuilder full_response = new StringBuilder();
        uint8 buffer[4096];
        size_t bytes_read;

		try {
			while ((bytes_read = input.read(buffer)) > 0) {
				buffer[bytes_read] = '\0';
				full_response.append_len((string)buffer, (long)bytes_read);
			}
		}
		catch (Error e) {
		}
        
        string raw = full_response.str;
        int json_start = raw.index_of("{");
        if (json_start == -1)
			return null;
        
        string json_data = raw.substring(json_start);

		var res = new GeminiResponse(json_data);
		return res;
    }

}
