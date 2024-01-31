use "collections"
use "http_server"
use "logger"
use "net"
use "promises"
use "regex"
use "valbytes"
use "debug"


interface URLHandler
  fun apply(r: Request val, m: Match val, b: ByteArrays, p: Responder iso)


interface DefaultHandler
  fun apply(r: Request val, b: ByteArrays, p: Responder iso)


class NotFoundHandler is DefaultHandler
  fun apply(r: Request val, b: ByteArrays, p: Responder iso) =>
    Debug("Returning empty response")
    (consume p)(StatusNotFound)

class RedirectTo
  fun apply(path: String val): BuildableResponse val =>
    recover val BuildableResponse(
    StatusTemporaryRedirect where content_length' = 0
    ).add_header("Location", path) end


type Route is (Regex val, URLHandler val)


class URLRouter
  let _routes: Array[Route] iso = recover Array[Route] end
  let _default_route: DefaultHandler val
  let _redirect_to_slash: Bool

  new create(default_route': DefaultHandler iso = NotFoundHandler, redirect_to_slash: Bool = true) =>
    _default_route = consume default_route'
    _redirect_to_slash = redirect_to_slash

  fun ref add(regex: Regex val, handler: URLHandler iso) =>
    _routes.push((regex, consume handler))

  fun ref add_many(routes: Array[Route] iso) =>
    _routes.append(consume routes)

  fun val _find_matching_handler(path: String val):
    ((Match val, URLHandler box) | (None, DefaultHandler box)) =>
    for (regex, handler) in _routes.values() do
      try
        return (recover val regex(path)? end, handler)
      end
    end
    Debug("No matching route found!")
    (None, _default_route)

  fun val handle_request(r: Request val, b: ByteArrays, p: Responder iso) =>
    let path = r.uri().path
    Debug("Path: " + path)

    // Redirect to slash at the end
    if _redirect_to_slash and not path.at("/", -1) then
      Debug("Redirect to slash")
      (consume p)(RedirectTo(path + "/"))
      return
    end

    match _find_matching_handler(path)
    | (let m: Match val, let handler: URLHandler box) => handler(r, m, b, consume p)
    | (None, let handler: DefaultHandler box) => handler(r, b, consume p)
    end
