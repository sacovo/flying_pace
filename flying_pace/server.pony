use "collections"
use "debug"
use "promises"

use "http_server"
use "logger"
use "net"
use "regex"
use "valbytes"


class _FPHandler is Handler
  let _session: Session
  var _request: (Request | None) = None
  var _body: ByteArrays = ByteArrays
  var _handler: (ResponseHandler tag | None) = None
  let _router: URLRouter val

  new create(session': Session, router: URLRouter val) => 
    Debug("Handler was created")
    _session = session'
    _router = router

  fun ref apply(request: Request val, request_id: USize val) =>
    _request = request
    _body = ByteArrays
    _handler = _ResponseHandler(_session, request_id)
    Debug("Handler was applyed")

  fun ref chunk(data: ByteSeq val, request_id: USize val) =>
    Debug("Received chunk of size: " + data.size().string())
    _body = _body + data

  fun ref cancelled(request_id: USize val) =>
    match _handler
    | let h: ResponseHandler tag => h.cancel(request_id)
    end
    dispose_handler()
    Debug("Request cancelled: " + request_id.string())

  fun ref failed(reason: RequestParseError, request_id: USize val) =>
    match _handler
    | let h: ResponseHandler tag => h.cancel(request_id)
    end
    dispose_handler()
    Debug("Request failed: " + request_id.string())

  fun ref closed() =>
    dispose_handler()
    Debug("Session closed")

  fun ref dispose_handler() =>
    match _handler
    | let handler: ResponseHandler tag => handler.dispose()
    end
    _handler = None

  fun ref finished(request_id: USize val) =>
    Debug("Request finished")
    match (_request, _handler)
    | (let request: Request, let handler: ResponseHandler tag) =>

      _router.handle_request(request, _body, handler)
      _request = None

    else
      Debug("Finish called without request!")
    end


class _FPHandlerFactory is HandlerFactory
  let _router: URLRouter val

  new create(router': URLRouter val) =>
    _router = router'

  fun box apply(session: Session tag): _FPHandler ref^ =>
    _FPHandler(session, _router)


class _FPServerNotify is ServerNotify
  let _server: FPServer

  new create(server: FPServer) =>
    _server = server


class _NoneLogger
  fun box apply(level: (Fine val | Info val | Warn val | Error val)): Bool =>
    false

  fun box log(msg: String val, loc: SourceLoc = __loc): Bool =>
    """
    """
    false


actor FPServer
  let _logger: (_NoneLogger | Logger[String])

  new create(
    router': URLRouter val,
    auth: TCPListenAuth,
    config: ServerConfig,
    logger: (None | Logger[String]) = None
  ) =>
    let server = Server(auth, _FPServerNotify(this), _FPHandlerFactory(router'), config)

    match logger
    | let logger': Logger[String] =>  _logger = logger'
    | None => _logger = _NoneLogger
    end
