public class Brain.AnthropicResponse : Brain.Response {
    public AnthropicResponse(string data_json) throws Error {
        base(data_json);
    }

    public override string parse_text_from_json(string raw_data) throws Error {
        int start = raw_data.index_of("{");
        int end = raw_data.last_index_of("}");

        if (start == -1 || end == -1 || end < start)
            throw new ResponseError.InvalidJson("Invalid JSON format");

        string clean_json = raw_data.substring(start, end - start + 1);
        var doc = YYJson.Doc.read(clean_json, clean_json.length);
        if (doc == null) throw new ResponseError.InvalidJson("Invalid JSON format");
        unowned var root = doc.get_root();

        check_api_error(root);

        // {"content": [{"type": "text", "text": "..."}]}, "thinking" and tool blocks are skipped
        unowned var content = root.obj_get("content");
        if (content != null && content.arr_size() > 0) {
            var answer = new StringBuilder();
            for (size_t i = 0; i < content.arr_size(); i++) {
                unowned var block = content.arr_get(i);
                unowned var type = block.obj_get("type");
                unowned var text = block.obj_get("text");
                if (type != null && type.get_str() == "text" && text != null && text.get_str() != null)
                    answer.append(text.get_str());
            }
            return answer.str;
        }

        throw new ResponseError.UnknownStructure("Unrecognized JSON structure: %s", clean_json);
    }
}

public class Brain.Anthropic : Brain.HttpClient {
    private const string ANTHROPIC_VERSION = "2023-06-01";

    public Anthropic(string model_id, string api_key) {
        this.host = "api.anthropic.com";
        this.model_id = model_id;
        this.api_key = api_key;
    }

    protected override string[] build_request(string prompt, out string endpoint, out string body) throws Error {
        var safe_prompt = prompt.make_valid();
        var doc = new YYJson.MutDoc();
        unowned var root = doc.obj();
        root.obj_add_str(doc, "model", this.model_id);
        root.obj_add_int(doc, "max_tokens", 32000);
        unowned var messages = root.obj_add_arr(doc, "messages");
        unowned var msg_obj = messages.arr_add_obj(doc);
        msg_obj.obj_add_str(doc, "role", "user");
        msg_obj.obj_add_str(doc, "content", safe_prompt);
        doc.set_root(root);

        string? payload = doc.write();
        if (payload == null) throw new ResponseError.InvalidJson("JSON serialization failed");

        endpoint = "/v1/messages";
        body = payload;
        return {
            "Content-Type: application/json",
            "x-api-key: " + this.api_key,
            "anthropic-version: " + ANTHROPIC_VERSION,
        };
    }

    protected override Response parse_response(string raw) throws Error {
        return new AnthropicResponse(raw);
    }
}
