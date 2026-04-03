void main()
{
	Intl.setlocale();

	try {
		var app = new Gemini("gemma-3-27b-it", "API_KEY");
		var result = app.send("Salut comment tu t'appelles ?");
		print ("%s\n", result.content);
	}
	catch (Error e) {
		print ("Error: %s\n", e.message);
	}
}
