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

class val TestRequest is Request
  new create() =>
    """
    """

  fun box method(): Method val => GET
  fun box uri(): URL val => URL
  fun box version(): HTTP10 val => HTTP10
  fun box header(name: String val): None => None
  fun box headers(): Iterator[(String val , String val)] => [].values()
  fun box has_body(): Bool val => false
  fun box content_length(): None => None
  fun box transfer_coding(): None => None
