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

        // {"content": [{"type": "text", "text": "..."}]}
        unowned var content = root.obj_get("content");
        if (content != null && content.arr_size() > 0) {
            unowned var first = content.arr_get(0);
            if (first != null) {
                unowned var text = first.obj_get("text");
                if (text != null) return text.get_str();
            }
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

    public override Response? send(string prompt) throws Error {
        var safe_prompt = prompt.make_valid();
        var doc = new YYJson.MutDoc();
        unowned var root = doc.obj();
        root.obj_add_str(doc, "model", this.model_id);
        root.obj_add_int(doc, "max_tokens", 1024);
        unowned var messages = root.obj_add_arr(doc, "messages");
        unowned var msg_obj = messages.arr_add_obj(doc);
        msg_obj.obj_add_str(doc, "role", "user");
        msg_obj.obj_add_str(doc, "content", safe_prompt);
        doc.set_root(root);

        string? payload = doc.write();
        if (payload == null) throw new ResponseError.InvalidJson("JSON serialization failed");

        var raw = send_request(
            "POST",
            "/v1/messages",
            {
                "Content-Type: application/json",
                "x-api-key: " + this.api_key,
                "anthropic-version: " + ANTHROPIC_VERSION,
            },
            payload
        );

        return new AnthropicResponse(raw);
    }
}
