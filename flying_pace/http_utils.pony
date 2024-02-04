use "debug"

use "http_server"
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
