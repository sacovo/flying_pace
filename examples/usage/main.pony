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


actor WSTimerResponse is WSResponse
  let _timers: Timers tag
  var _timer: (Timer tag  | None) = None
  var _counter: Counter tag
  var _session: (Session tag | None) = None
  var _rid: USize val = 0

  new create(timers: Timers, counter: Counter tag) =>
    _counter = counter
    _timers = timers

  be apply(session: Session, request_id: USize val) =>
    """
    """
    _session =  session
    _rid = request_id

    let notify = object iso is TimerNotify
      var c: USize val = 1
      fun ref apply(timer: Timer, count: U64): Bool => 
        Debug("Timer..")
        _counter.inc()
        let p = Promise[ISize val]
        let r' = request_id
        let s' = session
        let c' = _counter

        p.next[None]({(c: ISize val) => 
          let content = ByteArrays(c.string().array())
          let msg = WSMessage(content, Text, true)
          try
            msg.send_to(s', r')?
          else
            Debug("Error sending message to session")
          end

        })
        c'.get(p)

        true
    end
    let timer = Timer(consume notify, 1_000_000_000, 1_000_000_000)
    _timer = timer
    _timers(consume timer)

  be close(msg: WSMessage val) =>
    try
      _timers.cancel(_timer as Timer tag)
    end
    

  be message(msg: WSMessage val) =>
    """
    """
    match msg.string()
    | "+" => _counter.inc()
    | "-" => _counter.dec()
    else
      let msg' = WSMessage.from_string("Invalid command!")
      try
        msg'.send_to(_session as Session, _rid)?
      end
    end



actor Counter
  var _counter: ISize = 0

  be inc() => _counter = _counter + 1
  be dec() => _counter = _counter - 1

  be get(p: Promise[ISize val]) => p(_counter)


class App
  let _counter: Counter = Counter
  let _templates: FileTemplates val
  let _timers: Timers = Timers

  new create(templates: FileTemplates val) =>
    _templates = templates

  fun box hello(r: Request val, m: Match val, b: ByteArrays, p: ResponseHandler tag) =>
    let name = try recover val m.find[String iso]("name")? end else "World" end
    let p' = Promise[ISize val]

    p'.next[None]({(i: ISize val) => 
      let values = TemplateValues
      values("name") = name
      values("count") = i.string()
      p(_templates.render("index.html", r, values))
    })

    _counter.get(p')


  fun box greet(r: Request val, m: Match val, b: ByteArrays, p: ResponseHandler tag, name: String) =>
    (consume p)("Hello " + name + "!")

  fun box echo(r: Request val, m: Match val, b: ByteArrays, p: ResponseHandler tag) =>
    Debug("Called echo")
    p(b)

  fun box count(r: Request val, m: Match val, b: ByteArrays, p: ResponseHandler tag) =>
    let p' = Promise[ISize val]

    p'.next[None]({(i: ISize val) => 
      p(i.string())
    })

    _counter.get(p')

  fun box inc(r: Request val, m: Match val, b: ByteArrays, p: ResponseHandler tag) =>
    _counter.inc()
    count(r, m, b, p)

  fun box dec(r: Request val, m: Match val, b: ByteArrays, p: ResponseHandler tag) =>
    _counter.dec()
    count(r, m, b, p)

  fun box ws_timer(r: Request val, m: Match val, b: ByteArrays, p: ResponseHandler tag) =>
    Debug("Returning streaming")
    p.stream(WSTimerResponse(_timers, _counter))

  fun box timed(r: Request val, m: Match val, b: ByteArrays, p: ResponseHandler tag) =>
    let timers = Timers

    let notify = object iso is TimerNotify
    fun ref apply(timer: Timer, count: U64): Bool =>
      p("Hello")
      false
    end
    let timer = Timer(consume notify, 2_000_000_000, 1_000_000_000)
    timers(consume timer)

  fun box redirect(r: Request val, m: Match val, b: ByteArrays, p: ResponseHandler tag) =>
    (consume p)(RedirectTo("/redirect/"))

  fun box index(r: Request val, m: Match val, b: ByteArrays, p: ResponseHandler tag) =>
    let p' = Promise[ISize val]

    p'.next[None]({(i: ISize val) => 
      let values = TemplateValues
      let get = Params(r.uri().query)

      values("name") = get("name", "Sandro")
      values("count") = i.string()
      values("values") = Templates.string_values(["Hallo"; "Welt"].values())
      p(_templates.render("index.html", r, values))

    })

    _counter.get(p')

  fun box template(r: Request val, m: Match val, b: ByteArrays, p: ResponseHandler tag, name: String val) =>
    p(_templates.render(name, r))

  fun box post_example(r: Request val, m: Match val, b: ByteArrays, p: ResponseHandler tag) =>
  try
    let post = POSTData.decode(r, b)?
    let name = post("name", "Sandro")
    p(name)
  else
    p(StatusInternalServerError)
  end

  fun box json_example(r: Request val, m: Match val, b: ByteArrays, p: ResponseHandler tag) =>
    match JSON.parse(b)
    | let doc: JsonDoc => 
      p(JSON.render(doc))
    | (let e: USize val, let msg: String val) =>
      p(ServerError(msg))
    end


actor Main
  new create(env: Env) =>
    let config = ServerConfig("0.0.0.0", "8080")
    
    let templates = FileTemplates(f.FilePath(f.FileAuth(env.root), "templates/"))
    let app: App val = App(templates)

    let auth: BasicAuth val = BasicAuth("user", "password")

    let r: URLRouter val = recover val
      let router: URLRouter ref = URLRouter
      try
        router("/test2/")? = app~hello()
        router.add_many([
          Path("^/hello/(?<name>\\w+)/", app~hello())?
          Path("^/echo/", app~echo())?
          Path("^/count/", app~count())?
          Path("^/inc/", app~inc())?
          Path("^/dec/", app~dec())?
          Path("^/greet/", app~greet(where name = "John"))?
          Path("^/timer/", app~timed())?
          Path("^/redirect/", app~redirect())?
          Path("^\\/static\\/(?<path>\\S*)", ServeDirectory(f.FilePath(f.FileAuth(env.root), "static/") where list_dir = true))?
          Path("^/$", auth(app~index()))?
          Path("^/test/$", app~template(where name="test.html"))?
          Path("^/form/$", app~template(where name="form.html"))?
          Path("^/post-demo/$", app~post_example())?
          Path("^/json/$", app~json_example())?
          Path("^/ws/$", app~ws_timer())?
        ])
      else
        env.out.print("Error in creating routes!")
      end
      router
    end

    let server = FPServer(consume r, TCPListenAuth(env.root), config)
