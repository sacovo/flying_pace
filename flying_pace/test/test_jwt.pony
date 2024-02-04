use "encode/base64"
use "pony_test"

use "flying_pace"


class iso _TestJWT is UnitTest
  fun name(): String => "JWT"

  fun apply(h: TestHelper)? =>
    let jwt = JWT("secret1")
    let payload = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.5yDeOpW5CSQbX91bDg_M8taycvXTEvq6ntTkcSuJRfs"
    let b = jwt.get_signature("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ")

    h.assert_eq[String]("5yDeOpW5CSQbX91bDg_M8taycvXTEvq6ntTkcSuJRfs", b)

    let d = jwt.decode(payload)?
    h.assert_eq[String](d.data("name")? as String, "John Doe")

    let auth = JWTAuth("secret")

    let token = auth.issue()
    auth.validate(token)?

    let expired = auth.issue(-1000)

    h.assert_error(
      object
      fun box apply(): None val? =>
        auth.validate(expired)?
      end
    )
