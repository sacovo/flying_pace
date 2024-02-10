use "pony_test"
use "collections"
use "encode/base64"

use "crypto"
use "valbytes"

use "flying_pace"


class iso _TestWS is UnitTest
  fun name(): String => "WS"

  fun apply(h: TestHelper) =>
    // https://datatracker.ietf.org/doc/html/rfc4231
    let key = "KE/Yey7KciCCRCvIIWka5Q=="
    let gui: String val = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
    let resp = recover val Base64.encode_url(SHA1(key + gui), true) end

    h.assert_eq[String](resp, "0L3TyTsZNKzrtTODs6bOITQXYR8=")


class iso _TestDecode is UnitTest
  fun name(): String => "Decoder"

  fun apply(h: TestHelper)? =>
    let a: Array[U8 val] val = recover val [
      129; 136; 136; 35; 93; 205; 231; 85; 56; 191; 177; 19; 109; 253
    ] end

    (var msg, var r) = WSDecoder.decode(ByteArrays(a))?

    h.assert_eq[USize val](0, r.size())

    match msg
    | None => error
    | let msg': WSMessage val => 
      h.assert_true(msg'.opcode is Text)
      h.assert_eq[String](msg'.content.string(), "over9000")
    end

    (msg, r) = WSDecoder.decode(ByteArrays(a).select(0, 5))?

    match msg
    | None => h.assert_eq[USize](r.size(), 5)
    else
      error
    end


    let a' = ByteArrays([12; 45; 69])
    (msg, r) = WSDecoder.decode(ByteArrays(a, a'))?

    h.assert_eq[USize](a'.size(), r.size())
    for i in Range[USize](0, a'.size()) do
      h.assert_eq[U8](a'(i)?, r(i)?)
    end
