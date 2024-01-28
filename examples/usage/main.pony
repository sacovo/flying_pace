use "promises"
use "net"
use "flying_pace"
use "regex"
use "valbytes"
use "debug"
use "http_server"

actor App
  var _counter: USize = 0

  be hello(r: Request val, m: Match val, b: ByteArrays, p: Promise[ResponseType]) =>
    for group in m.groups().values() do
      Debug(group)
    end
    try
      let name = recover val m.find[String iso]("name")? end
      p("Hello " + name + "!")
    else
      p("Hello World!")
    end

  be echo(r: Request val, m: Match val, b: ByteArrays, p: Promise[ResponseType]) =>
    Debug("Called echo")
    p(b)

  be count(r: Request val, m: Match val, b: ByteArrays, p: Promise[ResponseType]) =>
    Debug("Called count")
    _counter = _counter + 1
    p(_counter.string())

actor Main
  new create(env: Env) =>
    let config = ServerConfig("localhost", "8080")
    
    let app = App

    let router = URLRouter
    try
      router.add_route(Regex("^/hello/(?<name>\\w+)/")?, app~hello())
      router.add_route(Regex("^/echo/")?, app~echo())
      router.add_route(Regex("^/count/")?, app~count())
    end

    let server = FPServer(router, TCPListenAuth(env.root), config)

