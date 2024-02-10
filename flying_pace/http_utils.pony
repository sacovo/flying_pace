use "debug"

use "http_server"
use "regex"
use "valbytes"


primitive ServerError

  fun val apply(b: ResponseBody): (ResponseBuilderHeaders iso^, ResponseBody) =>
    (
      recover iso
        Responses.builder()
          .set_status(StatusInternalServerError)
      end,
      b
    )


class NotFoundHandler is DefaultHandler
  fun apply(r: Request val, b: ByteArrays, p: ResponseHandler tag) =>
    Debug("Returning empty response")
    (consume p)(StatusNotFound)


class RedirectToHandler is DefaultHandler
  let _redirect_to: String val

  new create(redirect_to: String val = "/") =>
    _redirect_to = redirect_to

  fun apply(r: Request val, b: ByteArrays, p: ResponseHandler tag) =>
    p(RedirectTo(_redirect_to))


class RedirectTo
  fun apply(path: String val): (ResponseBuilderHeaders iso^, ResponseBody) =>
    (recover iso
      Responses.builder()
        .set_status(StatusTemporaryRedirect)
        .add_header("Location", path)
      end,
      ""
    )


actor _MethodRequiredHandler is URLHandler
  let _handler: URLHandler val
  let methods: Array[Method val] val

  new create(handler: URLHandler val, m': Array[Method val] val) =>
    _handler = handler
    methods = m'

  be apply(r: Request val, m: Match val, b: ByteArrays, p: ResponseHandler tag) =>
    if methods.contains(r.method()) then
      _handler(r, m, b, p)
    else
      p(StatusMethodNotAllowed)
    end


class MethodsRequired
  let m: Array[Method] val

  new create(m': Array[Method val] val) => m = m'

  fun apply(handler: URLHandler val): URLHandler val =>
    _MethodRequiredHandler(handler, m)~apply()


primitive POSTRequired
  fun apply(handler: URLHandler val): URLHandler val =>
    _MethodRequiredHandler(handler, [POST])~apply()


primitive GETRequired
  fun apply(handler: URLHandler val): URLHandler val =>
    _MethodRequiredHandler(handler, [GET])~apply()
