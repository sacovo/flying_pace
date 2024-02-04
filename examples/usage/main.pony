use "promises"
use "json"
use "templates"
use f = "files"
use "net"
use "flying_pace"
use "regex"
use "valbytes"
use "debug"
use "http_server"
use "time"


actor App
  var _counter: USize = 0
  let _templates: FileTemplates val

  new create(templates: FileTemplates val) =>
    _templates = templates

  be hello(r: Request val, m: Match val, b: ByteArrays, p: ResponseHandler tag) =>
    let name = try recover val m.find[String iso]("name")? end else "World" end
    let values = TemplateValues

    values("name") = name
    values("count") = _counter.string()
    p(_templates.render("index.html", r, values))

  be greet(r: Request val, m: Match val, b: ByteArrays, p: ResponseHandler tag, name: String) =>
    (consume p)("Hello " + name + "!")

  be echo(r: Request val, m: Match val, b: ByteArrays, p: ResponseHandler tag) =>
    Debug("Called echo")
    p(b)

  be count(r: Request val, m: Match val, b: ByteArrays, p: ResponseHandler tag) =>
    Debug("Called count")
    _counter = _counter + 1
    (consume p)(_counter.string())

  be timed(r: Request val, m: Match val, b: ByteArrays, p: ResponseHandler tag) =>
    let timers = Timers

    let notify = object iso is TimerNotify
    fun ref apply(timer: Timer, count: U64): Bool =>
      p("Hello")
      false
    end
    let timer = Timer(consume notify, 2_000_000_000, 1_000_000_000)
    timers(consume timer)

  be redirect(r: Request val, m: Match val, b: ByteArrays, p: ResponseHandler tag) =>
    (consume p)(RedirectTo("/redirect/"))

  be index(r: Request val, m: Match val, b: ByteArrays, p: ResponseHandler tag) =>
    let values = TemplateValues
    let get = Params(r.uri().query)

    values("name") = get("name", "Sandro")
    values("count") = _counter.string()
    p(_templates.render("index.html", r, values))

  be template(r: Request val, m: Match val, b: ByteArrays, p: ResponseHandler tag, name: String val) =>
    p(_templates.render(name, r))

  be post_example(r: Request val, m: Match val, b: ByteArrays, p: ResponseHandler tag) =>
  try
    let post = POSTData.decode(r, b)?
    let name = post("name", "Sandro")
    p(name)
  else
    p(StatusInternalServerError)
  end

  be json_example(r: Request val, m: Match val, b: ByteArrays, p: ResponseHandler tag) =>
    match JSON.parse(b)
    | let doc: JsonDoc => 
      p(JSON.render(doc))
    | (let e: USize val, let msg: String val) =>
      p(ServerError(msg))
    end


actor Main
  new create(env: Env) =>
    let config = ServerConfig("localhost", "8080")
    
    let templates = FileTemplates(f.FilePath(f.FileAuth(env.root), "templates/"))
    let app = App(templates)

    let auth: BasicAuth val = BasicAuth("user", "password")

    let r: URLRouter val = recover val
      let router: URLRouter ref = URLRouter
      try
        router("/test2/")? = app~hello()
        router.add_many([
          Path("^/hello/(?<name>\\w+)/", app~hello())?
          Path("^/echo/", app~echo())?
          Path("^/count/", app~count())?
          Path("^/greet/", app~greet(where name = "John"))?
          Path("^/timer/", app~timed())?
          Path("^/redirect/", app~redirect())?
          Path("^\\/static\\/(?<path>\\S*)", ServeDirectory(f.FilePath(f.FileAuth(env.root), "static/") where list_dir = true))?
          Path("^/$", auth(app~index()))?
          Path("^/test/$", app~template(where name="test.html"))?
          Path("^/form/$", app~template(where name="form.html"))?
          Path("^/post-demo/$", app~post_example())?
          Path("^/json/$", app~json_example())?
        ])
      else
        env.out.print("Error in creating routes!")
      end
      router
    end

    let server = FPServer(consume r, TCPListenAuth(env.root), config)
