use "debug"
use "encode/base64"
use "http_server"
use "pony_test"

use "crypto"

use "flying_pace"


actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  new make() => None

  fun tag tests(test: PonyTest) =>
    test(_TestHMAC)
    test(_TestJWT)
    test(_TestBasicAuth)
    test(_TestTemplate)
    test(_TestParams)
