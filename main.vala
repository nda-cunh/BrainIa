void main()
{
	Intl.setlocale();

	try {
		var app = Brain.create("gemma-3-27b-it", "Your_API_KEY");
		var result = app.send("Salut comment tu t'appelles ?");
		print ("%s\n", result.content);
	}
	catch (Error e) {
		print ("Error: %s\n", e.message);
	}
}
