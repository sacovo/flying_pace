use "encode/base64"
use "pony_test"

class iso _TestBasicAuth is UnitTest
  fun name(): String => "Basich Auth"

  fun apply(h: TestHelper) =>
    let user = "user"
    let password = "password"
    h.assert_eq[String](
      "dXNlcjpwYXNzd29yZA==",
      Base64.encode(user + ":" + password)
    )
