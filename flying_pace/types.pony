use "valbytes"
use "http_server"

type ResponseBody is (String val | ByteArrays)
type ResponseType is ((Response val, ResponseBody) | ResponseBody | Status val) 

