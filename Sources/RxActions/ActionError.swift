public enum ActionError: Error {
    /// The execution attempt was failed, since the `Action` was disabled.
    case disabled

    /// The unit of work emitted an error.
    case executionFailed(Error)
}