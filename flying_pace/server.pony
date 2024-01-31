use "collections"
use "debug"
use "logger"
use "net"
use "promises"
use "regex"

use "http_server"

use "valbytes"

class _FPHandler is Handler
  let _session: Session
  var _request: (Request | None) = None
  var _body: ByteArrays = ByteArrays
  var _server: FPServer
  let _router: URLRouter val

  new create(server: FPServer, session': Session, router: URLRouter val) => 
    Debug("Handler was created")
    _session = session'
    _server = server
    _router = router

  fun ref apply(request: Request val, request_id: USize val) =>
    _request = request
    _body = ByteArrays
    Debug("Handler was applyed")

  fun ref chunk(data: ByteSeq val, request_id: USize val) =>
    Debug("Received chunk of size: " + data.size().string())
    _body = _body + data

  fun ref finished(request_id: USize val) =>
    Debug("Request finished")
    match _request
    | let request: Request =>

      let handler = ResponseHandler(_session, request_id)
      let responder =recover iso Responder(handler) end
      _router.handle_request(request, _body, consume responder)
      _request = None

    | None => Debug("Finish called without request!")
    end


class _FPHandlerFactory is HandlerFactory
  let server: FPServer
  let router: URLRouter val

  new create(server': FPServer tag, router': URLRouter val) =>
    server = server'
    router = router'

  fun box apply(session: Session tag): _FPHandler ref^ =>
    _FPHandler(server, session, router)


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
  let router: URLRouter val
  let _server: Server
  let _logger: (_NoneLogger | Logger[String])

  new create(
    router': URLRouter val,
    auth: TCPListenAuth,
    config: ServerConfig,
    logger: (None | Logger[String]) = None
  ) =>
    router = router'
    _server = Server(auth, _FPServerNotify(this), _FPHandlerFactory(this, router'), config)

    match logger
    | let logger': Logger[String] =>  _logger = logger'
    | None => _logger = _NoneLogger
    end
