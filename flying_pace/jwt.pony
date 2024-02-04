use "debug"
use "encode/base64"
use "time"

use "crypto"
use "http_server"
use "json"
use "regex"
use "valbytes"


interface JWTURLHandler
  fun box apply(r: Request val, m: Match val, b: ByteArrays, jwt: JsonObject, p: ResponseHandler tag)


class val JWT
  let _hmac: HMAC

  new val create(secret: String val, hash: HashFn val = SHA256) =>
    _hmac = HMAC(secret, hash)

  fun val header(): String val =>
    let doc = JsonDoc
    let obj = JsonObject
    obj.data("alg") = alg_name()
    obj.data("typ") = "JWT"
    doc.data = obj

    Base64.encode_url(doc.string())

  fun val alg_name(): String val =>
    match _hmac.hash
    | let h: SHA256 => "HS256"
    | let h: SHA384 => "HS384"
    | let h: SHA512 => "HS512"
    else
      "none"
    end

  fun val payload(obj: JsonObject): String val =>
    let doc = JsonDoc
    doc.data = obj
    Base64.encode_url(doc.string())

  fun val get_signature(data: String val): String val =>
    let r = Base64.encode_url(_hmac(data)).array()
    // For some reason Base64 adds a 0 to the string if the argument is an array
    String.from_array(recover val r.slice(0, r.size() - 1) end)

  fun val sign(header': String val, payload': String val): String val =>
    let msg = recover val header' + "." + payload' end
    let signature = get_signature(msg)

    msg + "." + signature

  fun val apply(obj: JsonObject): String val =>
    sign(header(), payload(obj))

  fun val decode(jwt: String val): JsonObject? =>
    let split = jwt.split(".")
    let payload' = recover val String.from_iso_array(Base64.decode_url(split(1)?)?) end
    let header' = recover val String.from_iso_array(Base64.decode_url(split(0)?)?) end

    let header_doc = JsonDoc
    header_doc.parse(header')?
    let json = header_doc.data as JsonObject
    let alg = json.data("alg")? as String

    if not (alg == alg_name()) then error end

    let data = recover val split(0)? + "." + split(1)? end
    let signature_provided = split(2)?
    let signature_check = get_signature(data)

    if not ConstantTimeCompare[String box](signature_provided, signature_check) then
      error
    end

    let doc = JsonDoc
    doc.parse(payload')?
    doc.data as JsonObject


actor _JWTAuthHandler is URLHandler
  let _handler: (URLHandler val | JWTURLHandler val)
  let _jwt_auth: JWTAuth

  new create(handler: (URLHandler val | JWTURLHandler val), jwt_auth: JWTAuth) =>
    _handler = handler
    _jwt_auth = jwt_auth

  be apply(r: Request val, m: Match val, b: ByteArrays, p: ResponseHandler tag) =>
    match r.header("Authorization")
    | let h: String =>
      try
        let split = h.split(" ")
        let token = split(1)?
        let jwt = _jwt_auth.validate(token)?

        match _handler
        | let h': URLHandler val => h'(r, m, b, p)
        | let h': JWTURLHandler val => h'(r, m, b, jwt, p)
        end
        return
      end
    end
    p(StatusUnauthorized)


interface TestFunc
  fun apply(r: Request val, m: Match val, b: ByteArrays): JsonObject?


class JWTAuthView is URLHandler
  let _test: TestFunc
  let _jwt_auth: JWTAuth
  let _ttl: I64

  new create(test: TestFunc, jwt_auth: JWTAuth, ttl: I64 = 3600 * 24) =>
    _test = test
    _jwt_auth = jwt_auth
    _ttl = ttl

  fun box apply(r: Request val, m: Match val, b: ByteArrays, p: ResponseHandler tag) =>
    try

      let obj = _test(r, m, b)?
      return p(_jwt_auth.issue(_ttl, obj))
    end
    p(StatusUnauthorized)


class val JWTAuth
  let _jwt: JWT val

  new val create(secret: String val) =>
    _jwt = JWT(secret)

  fun val issue(ttl: I64 = 3600 * 24, obj: JsonObject = JsonObject): String val =>
    obj.data("exp") = Time.seconds() + ttl

    _jwt.apply(obj)

  fun val validate(token: String val): JsonObject? =>
    let obj = _jwt.decode(token)?

    if obj.data("exp")? as I64 < Time.seconds() then
      error
    end
    obj

  fun val apply(handler: (URLHandler val | JWTURLHandler val)): URLHandler val =>
    _JWTAuthHandler(handler, this)~apply()
