/**
* One message of a conversation sent with send_messages().
*/
public class Brain.Message {
	/** "user" or "assistant". */
	public string role;
	public string content;

	public Message(string role, string content) {
		this.role = role;
		this.content = content;
	}
}

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

	/**
	* Send a whole conversation: a system prompt and the messages, oldest first.
	* Providers cache prompts per message, so sending the fixed part as the system
	* prompt and each turn as its own message lets the next request reuse the cache.
	* The default implementation joins everything into one prompt for send().
	* @param system The system prompt (instructions), or null.
	* @param messages The user and assistant messages, oldest first.
	* @return The response of the model.
	* @throws Error On network or API error.
	*/
	public virtual Response? send_messages(string? system, Message[] messages) throws Error {
		return send(join_messages(system, messages));
	}

	/**
	* Asynchronous version of send_messages(), cancellable like send_async().
	*/
	public virtual async Response? send_messages_async(string? system, Message[] messages, Cancellable? cancellable = null) throws Error {
		return yield send_async(join_messages(system, messages), cancellable);
	}

	private static string join_messages(string? system, Message[] messages) {
		var bs = new StringBuilder(system ?? "");
		foreach (unowned var m in messages)
			bs.append("\n\n%s: %s".printf(m.role, m.content));
		return bs.str;
	}
}
