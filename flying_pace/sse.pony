use "http_server"


actor ServerSentEvents is StreamingResponse
  var _session: (Session | None) = None
  var _request_id: (USize val | None) = None

  be apply(session: Session, request_id: USize val) =>
    _session = session
    _request_id = request_id

  fun ref response(): ResponseBuilderHeaders ref =>
    Responses.builder()
      .set_status(StatusOK)
      .add_header("Content-Type", "text/event-stream")
      .add_header("Cache-Control", "no-store")

  be send_msg(msg: String val) =>
    match (_session, _request_id)
    | (let session: Session, let id: USize val) =>
      session.send_chunk(msg + "\n\n", id)
    end

  be done() =>
    match (_session, _request_id)
    | (let session: Session, let id: USize val) =>
      session.send_finished(id)
    end
