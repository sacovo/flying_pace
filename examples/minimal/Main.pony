use "http_server"
use "net"
use "valbytes"

class MyServerNotify is ServerNotify
  new create() =>
    """
    """

class SomeResponse
  fun apply(): BuildableResponse val =>
    recover val BuildableResponse(StatusOK where content_length' = 0) end


actor App
  be response(r: Wrapper val) =>
    r(SomeResponse())


class Wrapper
  let _handler: ResponseHandler tag

  new create(handler: ResponseHandler) =>
    _handler = handler

  fun val apply(response: Response) =>
    _handler(response)

actor ResponseHandler
  let _session: Session
  let _request_id: USize val

  new create(session: Session, request_id: USize val) =>
    _session = session
    _request_id = request_id

  be apply(response: Response) =>
    let b = ByteArrays
    _session.send(response, b, _request_id)


class MyHandler is HandlerWithoutContext
  let _session: Session
  let _app: App = App

  new create(session: Session) =>
    _session = session

  fun ref finished(request_id: USize val) =>
    let handler = ResponseHandler(_session, request_id)
    let wrapper = recover val Wrapper(handler) end

    _app.response(wrapper)


actor Main
  new create(env: Env) =>
    let config = ServerConfig("localhost", "8080")

    let s = Server(
      TCPListenAuth(env.root),
      MyServerNotify,
      SimpleHandlerFactory[MyHandler],
      config
    )
