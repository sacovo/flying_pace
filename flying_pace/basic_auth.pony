use "encode/base64"

use "http_server"
use "regex"
use "valbytes"


actor _BasicAuthHandler is URLHandler
  let _handler: URLHandler val
  let _credentials: String

  new create(handler: URLHandler val, credentials: String val) =>
    _handler = handler
    _credentials = credentials

  be apply(r: Request val, m: Match val, b: ByteArrays, p: ResponseHandler tag) =>
    match r.header("Authorization")
    | _credentials => 
        _handler(r, m, b, p)
    else
      p(
        (recover iso
          Responses.builder()
            .set_status(StatusUnauthorized)
            .add_header("WWW-Authenticate", "Basic realm=\"User Visible Realm\"")
        end, ""
        )
      )
    end


class BasicAuth
  let _credentials: String val

  new create(user: String val, password: String val) =>
    _credentials = "Basic " + Base64.encode(user + ":" + password)

  fun box apply(handler: URLHandler val): URLHandler val =>
    _BasicAuthHandler(handler, _credentials)~apply()
