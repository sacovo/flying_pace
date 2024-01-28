use "collections"
use "http_server"
use "logger"
use "net"
use "promises"
use "regex"
use "valbytes"


interface URLHandler
  fun apply(r: Request val, m: Match val, b: ByteArrays, p: Promise[ResponseType])


interface DefaultHandler
  fun apply(r: Request val, b: ByteArrays, p: Promise[ResponseType])

  
actor URLRouter
  let routes: Array[(Regex val, URLHandler ref)] = Array[(Regex val, URLHandler ref)]
  var default_route: (DefaultHandler ref | None) = NotFoundHandler

  be add_route(regex: Regex val, handler: URLHandler iso) =>
    """
    Add a route to the router, routes are evaluted in the order they
    were added to the router. Routes added first are evaluted first.

    So if you want to use a catch all router, you should add it last,
    as otherwise it would macth all routes.
    """
    routes.push((regex, consume handler))

  be set_default_handler(handler: (DefaultHandler iso | None)) =>
    default_route = consume handler


  be handle_request(r: Request val, b: ByteArrays, p: Promise[ResponseType]) =>
    let path = r.uri().path

    // Redirect to slash at the end
    if not path.at("/", -1) then
      let redirect = recover
        val BuildableResponse(
          StatusTemporaryRedirect where content_length' = 0
        ).add_header("Location", path + "/") end

      p((redirect, ""))
      return
    end

    for (regex, handler) in routes.values() do
      try
        let m = recover val regex(path)? end
        handler(r, m, b, p)
        return
      end

    else
      match default_route
      | let handler: DefaultHandler => handler(r, b, p)
      | None => p(StatusNotFound)
      end
    end
    p(StatusNotFound)




