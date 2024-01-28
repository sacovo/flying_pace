use "collections"
use "http_server"
use "debug"
use "logger"
use "net"
use "promises"
use "regex"
use "valbytes"


class ResponseHandler
  
  let session: Session
  let request_id: USize val

  new create(session': Session, request_id': USize val) =>
    session = session'
    request_id = request_id'

  fun _ensure_bytes(b: ResponseBody): ByteArrays =>
    match b
    | let b': ByteArrays => b'
    | let b': String => ByteArrays(b'.array())
    end

  fun apply(r: ResponseType val) =>
    """
    """
    Debug("Creating response")
    (let r': Response, let b: ByteArrays) = match r
    | (let response: Response, let body: ResponseBody) => (response, _ensure_bytes(body))
    | let body: ResponseBody =>
      let response = recover val BuildableResponse(StatusOK where content_length' = body.size()) end
      (response, _ensure_bytes(body))
    | let status: Status =>
      let body = status.string()
      let response = recover val BuildableResponse(status where content_length' = body.size()) end
      (response, _ensure_bytes(body))
    end
    Debug("Sending Response")
    session.send(r', b, request_id)
    Debug("Response sent")
    

class NotFoundHandler is DefaultHandler
  fun apply(r: Request val, b: ByteArrays, p: Promise[ResponseType]) =>
    Debug("Returning empty response")
    p(StatusNotFound)
