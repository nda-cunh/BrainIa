public class Brain.GeminiResponse: Response {

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
        var doc = YYJson.Doc.read(clean_json, clean_json.length);
        if (doc == null) throw new ResponseError.InvalidJson("Invalid JSON format: %s", raw_data);
        unowned var root = doc.get_root();

        check_api_error(root);

        unowned var candidates = root.obj_get("candidates");
        if (candidates != null && candidates.arr_size() > 0) {
            unowned var first = candidates.arr_get(0);
            if (first != null) {
                unowned var content = first.obj_get("content");
                if (content != null) {
                    unowned var parts = content.obj_get("parts");
                    if (parts != null && parts.arr_size() > 0) {
                        unowned var part = parts.arr_get(0);
                        if (part != null) {
                            unowned var text = part.obj_get("text");
                            if (text != null) return text.get_str();
                        }
                    }
                }
            }
        }

        throw new ResponseError.UnknownStructure("Unrecognized JSON structure: %s", clean_json);
    }
}


public class Brain.Gemini: HttpClient {

    public Gemini(string model_id, string api_key) {
        this.model_id = model_id;
        this.api_key = api_key;
        this.host = "generativelanguage.googleapis.com";
    }

    public override Response? send(string prompt) throws Error {
        var safe_prompt = prompt.make_valid();
        var doc = new YYJson.MutDoc();
        unowned var root = doc.obj();
        unowned var contents = root.obj_add_arr(doc, "contents");
        unowned var content_obj = contents.arr_add_obj(doc);
        unowned var parts = content_obj.obj_add_arr(doc, "parts");
        unowned var part_obj = parts.arr_add_obj(doc);
        part_obj.obj_add_str(doc, "text", safe_prompt);
        doc.set_root(root);

        string? payload = doc.write();
        if (payload == null) throw new ResponseError.InvalidJson("JSON serialization failed");
        var payload_utf8 = payload.make_valid();

        var raw = send_request(
            "POST",
            "/v1beta/models/%s:generateContent".printf(this.model_id),
            {
                "Content-Type: application/json",
                @"x-goog-api-key: $(this.api_key)"
            },
            payload_utf8
        );

        return new GeminiResponse(raw._strip());
    }

}
