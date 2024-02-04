use "pony_test"

use "flying_pace"


class _TestParams is UnitTest
  fun name(): String => "Params"

  fun apply(h: TestHelper) =>
    let p = Params("test=hello")

    h.assert_eq[String](
      p("test"),
      "hello"
    )

    h.assert_eq[String](
      p("other"),
      ""
    )
