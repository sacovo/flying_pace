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
  var _route: (URLHandler tag | None) = None
  let _max_request_size: USize val

  new create(session': Session, router: URLRouter val, max_request_size: USize val) => 
    Debug("Handler was created")
    _session = session'
    _router = router
    _max_request_size = max_request_size

  fun ref apply(request: Request val, request_id: USize val) =>
    Debug(request.method().string() + " " + request.uri().path)
    for header in request.headers() do
      (let k: String, let v: String) = header
      Debug(k + ": " + v)
    end

    _request = request
    _body = ByteArrays

    match request.header("Upgrade")
    | "websocket" =>
      let ws_handler = _WSHandler(
        _session,
        request_id,
        _router,
        request
      )

      ws_handler.start()
      _session.upgrade(WSTCPNotify(ws_handler))
    else
      _handler = _ResponseHandler(
        _session,
        request_id,
        _router,
        request,
        _max_request_size
      )
    end

  fun ref chunk(data: ByteSeq val, request_id: USize val) =>
    match _handler
    | let h: ResponseHandler tag => h.chunk(data)
    end

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
    match _handler
    | let h: ResponseHandler tag => h.finished(request_id)
    end


class _FPHandlerFactory is HandlerFactory
  let _router: URLRouter val
  let _max_request_size: USize val

  new create(router': URLRouter val, max_request_size: USize val) =>
    _router = router'
    _max_request_size = max_request_size

  fun box apply(session: Session tag): _FPHandler ref^ =>
    _FPHandler(session, _router, _max_request_size)


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
    max_request_size: USize val = 500_000_000,
    logger: (None | Logger[String]) = None
  ) =>
    let server = Server(auth, _FPServerNotify(this), _FPHandlerFactory(router', max_request_size), config)

    match logger
    | let logger': Logger[String] =>  _logger = logger'
    | None => _logger = _NoneLogger
    end
