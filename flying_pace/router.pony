use "collections"
use "debug"
use "promises"

use "http_server"
use "logger"
use "net"
use "regex"
use "valbytes"


type Route is (Regex val, URLHandler val)


class Path
  fun apply(s: String, h: URLHandler val): Route? =>
    (recover val Regex(s)? end, h)


interface URLHandler
  fun box apply(r: Request val, m: Match val, b: ByteArrays, p: ResponseHandler tag)


interface DefaultHandler
  fun box apply(r: Request val, b: ByteArrays, p: ResponseHandler tag)


type PathHandler is ((Match val, URLHandler box) | (DefaultHandler box))


class URLRouter
  embed _routes: Array[Route] iso = recover Array[Route] end
  let _default_route: DefaultHandler val
  let _redirect_to_slash: Bool

  new create(default_route': DefaultHandler iso = NotFoundHandler, redirect_to_slash: Bool = true) =>
    _default_route = consume default_route'
    _redirect_to_slash = redirect_to_slash

  fun ref update(path: String val, value: URLHandler iso)? =>
    _routes.push((recover val Regex(path)? end, consume value))

  fun ref add_many(routes: Array[Route] iso) =>
    _routes.append(consume routes)

  fun val find_matching_handler(path: String val): PathHandler =>
    for (regex, handler) in _routes.values() do
      try
        return (recover val regex(path)? end, handler)
      end
    end
    Debug("No matching route found!")
    _default_route

  fun val handle_request(r: Request val, b: ByteArrays, p: ResponseHandler tag) =>
    let path = r.uri().path
    Debug("Path: " + path)

    match find_matching_handler(path)
    | (let m: Match val, let handler: URLHandler box) => return handler(r, m, b, p)
    end

    if _redirect_to_slash and not path.at("/", -1) then
      Debug("Redirect to slash")
      p(RedirectTo(path + "/"))
      return
    end

    _default_route(r, b, p)
