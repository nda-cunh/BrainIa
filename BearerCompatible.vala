public class Brain.ChatApiResponse : Brain.Response {
    public ChatApiResponse(string data_json) throws Error {
        base(data_json);
    }

    public override string parse_text_from_json(string raw_data) throws Error {
        int start = raw_data.index_of("{");
        int end = raw_data.last_index_of("}");

        if (start == -1 || end == -1) throw new ResponseError.InvalidJson("Invalid JSON format");

        string clean_json = raw_data.substring(start, end - start + 1);
        var doc = YYJson.Doc.read(clean_json, clean_json.length);
        if (doc == null) throw new ResponseError.InvalidJson("Invalid JSON format");
        unowned var root = doc.get_root();

        check_api_error(root);
        read_usage(root);

        unowned var choices = root.obj_get("choices");
        if (choices != null) {
            unowned var first = choices.arr_get(0);
            if (first != null) {
                unowned var message = first.obj_get("message");
                if (message != null) {
                    unowned var content = message.obj_get("content");
                    if (content != null) return text_of_content(content);
                }
            }
        }

        throw new ResponseError.UnknownStructure("Unrecognized JSON structure: %s", clean_json);
    }

    /**
    * Text of a message content: either a plain string, or a list of chunks whose
    * "text" chunks are concatenated (Mistral reasoning models also send "thinking"
    * chunks, which are skipped). A null content, e.g. tool calls only, gives "".
    * @param content The "content" value of the message.
    * @return The text of the answer.
    */
    private static string text_of_content(YYJson.Value content) {
        unowned string? str = content.get_str();
        if (str != null)
            return str;

        var text = new StringBuilder();
        for (size_t i = 0; i < content.arr_size(); i++) {
            unowned var chunk = content.arr_get(i);
            unowned var type = chunk.obj_get("type");
            unowned var chunk_text = chunk.obj_get("text");
            if (type != null && type.get_str() == "text" && chunk_text != null && chunk_text.get_str() != null)
                text.append(chunk_text.get_str());
        }
        return text.str;
    }
}

public class Brain.OpenAiCompatible : Brain.HttpClient {
    protected string endpoint;

    public OpenAiCompatible(string host, string endpoint, string model_id, string api_key) {
        this.host = host;
        this.endpoint = endpoint;
        this.model_id = model_id;
        this.api_key = api_key;
    }

    protected override string[] build_request(string prompt, out string endpoint, out string body) throws Error {
        var safe_prompt = prompt.make_valid();
        var doc = new YYJson.MutDoc();
        unowned var root = doc.obj();
        root.obj_add_str(doc, "model", this.model_id);
        unowned var messages = root.obj_add_arr(doc, "messages");
        unowned var msg_obj = messages.arr_add_obj(doc);
        msg_obj.obj_add_str(doc, "role", "user");
        msg_obj.obj_add_str(doc, "content", safe_prompt);
        doc.set_root(root);

        string? payload = doc.write();
        if (payload == null) throw new ResponseError.InvalidJson("JSON serialization failed");
        var payload_utf8 = payload.make_valid();

        debug("JSON payload sent: %s", payload_utf8);

        endpoint = this.endpoint;
        body = payload_utf8;
        return {
            "Content-Type: application/json",
            "Authorization: Bearer " + this.api_key,
        };
    }

    protected override Response parse_response(string raw) throws Error {
        return new ChatApiResponse(raw);
    }
}
