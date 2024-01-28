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

  new create(server: FPServer, session': Session) => 
    Debug("Handler was created")
    _session = session'
    _server = server

  fun ref apply(request: Request val, request_id: USize val) =>
    _request = request
    _body = ByteArrays
    Debug("Handler was applyed")

  fun ref chunk(data: ByteSeq val, request_id: USize val) =>
    Debug("Received chunk of size: " + data.size().string())
    _body = _body + data

  fun ref finished(request_id: USize val) =>
    Debug("Request finished")
    try
      let request: Request = _request as Request
      _server.handle_request(request, _body, request_id, _session)
    end

class _FPHandlerFactory is HandlerFactory
  let server: FPServer

  new create(server': FPServer tag) =>
    server = server'
    
  fun box apply(session: Session tag): _FPHandler ref^ =>
    _FPHandler(server, session)

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
  let _router: URLRouter
  let _server: Server
  let _logger: (_NoneLogger | Logger[String])

  new create(
    router': URLRouter,
    auth: TCPListenAuth,
    config: ServerConfig,
    logger: (None | Logger[String]) = None
  ) =>
    _router = router'
    _server = Server(auth, _FPServerNotify(this), _FPHandlerFactory(this), config)

    match logger
    | let logger': Logger[String] =>  _logger = logger'
    | None => _logger = _NoneLogger
    end

  be handle_request(request: Request, body: ByteArrays, request_id: USize val, session: Session) =>
    _logger(Fine) and _logger.log(
      "Handling request with id: " + request_id.string()
    )

    let p = Promise[ResponseType]
    let handler = recover iso ResponseHandler(session, request_id) end

    p.next[ResponseType]({(r: ResponseType) => 
      Debug("Promise was fullfilled")
      r
    }).next[None](consume handler)

    _router.handle_request(request, body, p)
