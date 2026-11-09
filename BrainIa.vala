public abstract class Brain.BrainIa {
	public abstract Response? send(string prompt) throws Error;
	public string model_id {get; protected set;}
	public string api_key {get; protected set;}

	/**
	* Asynchronous version of send(): the main loop keeps running while the request is in flight.
	* The default implementation runs send() in a thread (it cannot be interrupted);
	* the HTTP clients override it with a non-blocking request that cancellable aborts.
	* @param prompt The message to send.
	* @param cancellable Cancel the request; it then throws IOError.CANCELLED.
	* @return The response of the model.
	* @throws Error On network or API error, or IOError.CANCELLED.
	*/
	public virtual async Response? send_async(string prompt, Cancellable? cancellable = null) throws Error {
		SourceFunc callback = send_async.callback;
		Response? res = null;
		Error? err = null;
		new Thread<void>("brain-send", () => {
			try {
				res = send(prompt);
			}
			catch (Error e) {
				err = e;
			}
			Idle.add((owned) callback);
		});
		yield;
		if (cancellable != null)
			cancellable.set_error_if_cancelled();
		if (err != null)
			throw err;
		return res;
	}
}
