use "collections"
use "debug"
use "net"
use "promises"

use "http_server"
use "logger"
use "regex"
use "valbytes"


interface Middleware
  fun apply(headers: ResponseBuilderHeaders): ResponseBuilderHeaders


trait StreamingResponse

  be init(session: Session, request_id: USize val) =>
    session.send_raw(
      response()
      .finish_headers()
      .build(), request_id)

  be apply(session: Session, request_id: USize val)

  fun ref response(): ResponseBuilderHeaders ref =>
    Responses.builder()
      .set_status(StatusOK)
      .set_transfer_encoding(Chunked)

  be cancel(request_id: USize val) =>
    """
    """

  be dispose() => 
    """
    """


trait Responsable
  fun response(): (ResponseBuilderHeaders iso^, ResponseBody)


type ResponseBody is (String val | ByteArrays val)


type OneShotResponse is (
    (ResponseBuilderHeaders iso, ResponseBody)
  | ResponseBody
  | Status val
)


type ResponseType is (OneShotResponse val | StreamingResponse tag)


interface ResponseHandler
  be apply(r: OneShotResponse)
  be stream(r: StreamingResponse tag)
  be cancel(request_id: USize)
  be dispose()


actor _ResponseHandler is ResponseHandler
  let _session: Session
  let _request_id: USize val
  var _streaming: (StreamingResponse tag | None) = None
  embed _middlewares: Array[Middleware] = Array[Middleware]

  new create(session': Session, request_id': USize val) =>
    _session = session'
    _request_id = request_id'

  be apply(r: OneShotResponse) =>
    (let headers: ResponseBuilderHeaders, let body: ResponseBody) = _get_response(consume r)
    let data = _to_byte_iter(_apply_middlware(headers), body)
    _session.send_raw(data, _request_id)
    _session.send_finished(_request_id)

  fun ref _apply_middlware(headers: ResponseBuilderHeaders): ResponseBuilderHeaders =>
    var headers' = headers
    for m in _middlewares.values() do
      headers' = m(headers')
    end
    headers'

  be stream(r: StreamingResponse tag) =>
    _handle_streaming(r)

  be cancel(request_id': USize val) =>
    Debug("Request was cancelled")
    match _streaming
    | let s: StreamingResponse tag =>
      s.cancel(request_id')
    end

  fun _ensure_bytes(b: ResponseBody): ByteArrays =>
    match b
    | let b': ByteArrays => b'
    | let b': String => ByteArrays(b'.array())
    end

  fun _to_byte_iter(h: ResponseBuilderHeaders, b: ResponseBody): ByteSeqIter val =>
    h.add_header("Content-Length", b.size().string())
      .finish_headers()
      .add_chunk(b.array())
      .build()

  fun _get_response(r: OneShotResponse): (ResponseBuilderHeaders, ResponseBody) =>
    match r
    | (let h: ResponseBuilderHeaders iso, let b: ResponseBody) => (consume h, b)
    | (let b: ResponseBody) => (Responses.builder().set_status(StatusOK), b)
    | (let s: Status) => (Responses.builder().set_status(s), s.string())
    end

  fun ref _handle_streaming(r: StreamingResponse tag) =>
    r.init(_session, _request_id)
    r.apply(_session, _request_id)
    _streaming = r

  be dispose() =>
    Debug("Deposing handler")
    match _streaming
    | let s: StreamingResponse tag =>
      s.dispose()
    end
    _streaming = None
