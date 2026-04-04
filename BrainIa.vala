public abstract class Brain.BrainIa {
	public abstract Response? send(string prompt) throws Error;
	public string model_id {get; protected set;}
	public string api_key {get; protected set;}
}
