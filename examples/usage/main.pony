use "promises"
use "net"
use "flying_pace"
use "regex"
use "valbytes"
use "debug"
use "http_server"
use "time"

actor CounterResponse is StreamingResponse
  be apply(session: Session, request_id: USize val) =>
    session.send_chunk("Test\n", request_id)

class Path
  fun apply(s: String, h: URLHandler val): Route? =>
    (recover val Regex(s)? end, h)


actor App
  var _counter: USize = 0

  be hello(r: Request val, m: Match val, b: ByteArrays, p: Responder iso) =>
    let name = try recover val m.find[String iso]("name")? end else "World" end
    (consume p)("Hello " + name + "!")

  be greet(r: Request val, m: Match val, b: ByteArrays, p: Responder iso, name: String) =>
    (consume p)("Hello " + name + "!")

  be echo(r: Request val, m: Match val, b: ByteArrays, p: Responder iso) =>
    Debug("Called echo")
    (consume p)(b)

  be count(r: Request val, m: Match val, b: ByteArrays, p: Responder iso) =>
    Debug("Called count")
    _counter = _counter + 1
    (consume p)(_counter.string())

  be streaming(r: Request val, m: Match val, b: ByteArrays, p: Responder iso) =>
    (consume p).stream(CounterResponse)

  be timed(r: Request val, m: Match val, b: ByteArrays, p: Responder val) =>
    let timers = Timers

    let notify = object iso is TimerNotify
    fun ref apply(timer: Timer, count: U64): Bool =>
      p("Hello")
      false
    end
    let timer = Timer(consume notify, 2_000_000_000, 1_000_000_000)
    timers(consume timer)

  be redirect(r: Request val, m: Match val, b: ByteArrays, p: Responder val) =>
    (consume p)(RedirectTo("/redirect/"))

actor Main
  new create(env: Env) =>
    let config = ServerConfig("localhost", "8080")
    
    let app = App

    let r: URLRouter val = recover val
      let router: URLRouter ref = URLRouter
      try
        router.add_many([
          Path("^/hello/(?<name>\\w+)/", app~hello())?
          Path("^/echo/", app~echo())?
          Path("^/count/", app~count())?
          Path("^/stream/", app~streaming())?
          Path("^/greet/", app~greet(where name = "John"))?
          Path("^/timer/", app~timed())?
          Path("^/redirect/", app~redirect())?
        ])
      end
      router
    end

    let server = FPServer(consume r, TCPListenAuth(env.root), config)

