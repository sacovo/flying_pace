use "collections"
use "http_server"
use "debug"
use "logger"
use "net"
use "promises"
use "regex"
use "valbytes"


class Responder
  let _handler: ResponseHandler tag

  new create(handler: ResponseHandler) =>
    _handler = handler

  fun iso apply(response: OneShotResponse) =>
    _handler(response)

  fun iso stream(response: StreamingResponse tag) =>
    _handler.stream(response)


actor ResponseHandler
  
  let session: Session
  let request_id: USize val
  var _streaming: (StreamingResponse tag | None) = None

  new create(session': Session, request_id': USize val) =>
    session = session'
    request_id = request_id'

  be apply(r: OneShotResponse) =>
    _handle_oneshot(r)

  be stream(r: StreamingResponse tag) =>
    _handle_streaming(r)

  fun cancelled(request_id': USize val) =>
    match _streaming
    | let s: StreamingResponse tag =>
      s.cancel(request_id')
    end

  fun _ensure_bytes(b: ResponseBody): ByteArrays =>
    match b
    | let b': ByteArrays => b'
    | let b': String => ByteArrays(b'.array())
    end

  fun _get_response(r: OneShotResponse): (Response val, ByteArrays) =>
    match r
    | (let response: Response, let body: ResponseBody) => (response, _ensure_bytes(body))
    | let response: Response => (response, _ensure_bytes(""))
    | let body: ResponseBody =>
      let response = recover val BuildableResponse(StatusOK where content_length' = body.size()) end
      (response, _ensure_bytes(body))
    | let status: Status =>
      let body = status.string()
      let response = recover val BuildableResponse(status where content_length' = body.size()) end
      (response, _ensure_bytes(body))
    | let r': Responsable val=>
      _get_response(r'.response())
    end

  fun _handle_oneshot(r: OneShotResponse) => 
    (let r': Response, let b: ByteArrays) = _get_response(r)
    session.send(r', b, request_id)
    
  fun ref _handle_streaming(r: StreamingResponse tag) =>
    r.init(session, request_id)
    r.apply(session, request_id)
    _streaming = r
    

