use "pony_test"

use "crypto"

use "flying_pace"


class iso _TestHMAC is UnitTest
  fun name(): String => "HMAC"

  fun apply(h: TestHelper) =>
    // https://datatracker.ietf.org/doc/html/rfc4231
    let data = "what do ya want for nothing?"

    let hmac256 = HMAC("Jefe", SHA256)
    h.assert_eq[String](
      ToHexString(hmac256(data)),
      "5bdcc146bf60754e6a042426089575c7" +
      "5a003f089d2739839dec58b964ec3843"
    )

    let hmac384 = HMAC("Jefe", SHA384)
    h.assert_eq[String](
      ToHexString(hmac384(data)),
      "af45d2e376484031617f78d2b58a6b1b" +
      "9c7ef464f5a01b47e42ec3736322445e" +
      "8e2240ca5e69e2c78b3239ecfab21649"
    )

    let hmac512 = HMAC("Jefe", SHA512)
    h.assert_eq[String](
      ToHexString(hmac512(data)),
      "164b7a7bfcf819e2e395fbe73b56e0a3" +
      "87bd64222e831fd610270cd7ea250554" +
      "9758bf75c05a994a6d034f65f8f0e6fd" +
      "caeab1a34d4a6b4b636e070a38bce737"
    )
